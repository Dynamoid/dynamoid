# frozen_string_literal: true

require_relative 'key_fields_detector'
require_relative 'nonexistent_fields_detector'
require_relative 'where_conditions'

module Dynamoid
  module Criteria
    # The criteria chain is equivalent to an ActiveRecord relation (and realistically I should change the name from
    # chain to relation). It is a chainable object that builds up a query and eventually executes it by a Query or Scan.
    class Chain
      attr_reader :source, :consistent_read, :key_fields_detector

      include Enumerable

      ALLOWED_FIELD_OPERATORS = Set.new(
        %w[
          eq ne gt lt gte lte between begins_with in contains not_contains null not_null
        ]
      ).freeze

      # Create a new criteria chain.
      #
      # @param [Class] source the class upon which the ultimate query will be performed.
      def initialize(source)
        @where_conditions = WhereConditions.new
        @source = source
        @consistent_read = false
        @scan_index_forward = true

        # we should re-initialize keys detector every time we change @where_conditions
        @key_fields_detector = KeyFieldsDetector.new(@where_conditions, @source)
      end

      # Returns a chain which is a result of filtering current chain with the specified conditions.
      #
      # It accepts conditions in the form of a hash.
      #
      #   Post.where(links_count: 2)
      #
      # A key could be either string or symbol.
      #
      # In order to express conditions other than equality predicates could be used.
      # Predicate should be added to an attribute name to form a key +'created_at.gt' => Date.yesterday+
      #
      # Currently supported following predicates:
      # - +gt+ - greater than
      # - +gte+ - greater or equal
      # - +lt+ - less than
      # - +lte+ - less or equal
      # - +ne+ - not equal
      # - +between+ - an attribute value is greater than the first value and less than the second value
      # - +in+ - check an attribute in a list of values
      # - +begins_with+ - check for a prefix in string
      # - +contains+ - check substring or value in a set or array
      # - +not_contains+ - check for absence of substring or a value in set or array
      # - +null+ - attribute doesn't exists in an item
      # - +not_null+ - attribute exists in an item
      #
      # All the predicates match operators supported by DynamoDB's
      # {ComparisonOperator}[https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Condition.html#DDB-Type-Condition-ComparisonOperator]
      #
      #   Post.where('size.gt' => 1000)
      #   Post.where('size.gte' => 1000)
      #   Post.where('size.lt' => 35000)
      #   Post.where('size.lte' => 35000)
      #   Post.where('author.ne' => 'John Doe')
      #   Post.where('created_at.between' => [Time.now - 3600, Time.now])
      #   Post.where('category.in' => ['tech', 'fashion'])
      #   Post.where('title.begins_with' => 'How long')
      #   Post.where('tags.contains' => 'Ruby')
      #   Post.where('tags.not_contains' => 'Ruby on Rails')
      #   Post.where('legacy_attribute.null' => true)
      #   Post.where('optional_attribute.not_null' => true)
      #
      # There are some limitations for a sort key. Only following predicates
      # are supported - +gt+, +gte+, +lt+, +lte+, +between+, +begins_with+.
      #
      # +where+ without argument will return the current chain.
      #
      # Multiple calls can be chained together and conditions will be merged:
      #
      #   Post.where('size.gt' => 1000).where('title' => 'some title')
      #
      # It's equivalent to:
      #
      #   Post.where('size.gt' => 1000, 'title' => 'some title')
      #
      # But only one condition can be specified for a certain attribute. The
      # last specified condition will override all the others. Only condition
      # 'size.lt' => 200 will be used in following examples:
      #
      #   Post.where('size.gt' => 100, 'size.lt' => 200)
      #   Post.where('size.gt' => 100).where('size.lt' => 200)
      #
      # Internally +where+ performs either +Scan+ or +Query+ operation.
      #
      # Conditions can be specified as an expression as well:
      #
      #   Post.where('links_count = :v', v: 2)
      #
      # This way complex expressions can be constructed (e.g. with AND, OR, and NOT
      # keyword):
      #
      #   Address.where('city = :c AND (post_code = :pc1 OR post_code = :pc2)', city: 'A', pc1: '001', pc2: '002')
      #
      # See documentation for condition expression's syntax and examples:
      # - https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.OperatorsAndFunctions.html
      # - https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.FilterExpression.html
      #
      # @return [Dynamoid::Criteria::Chain]
      # @since 0.2.0
      def where(conditions, placeholders = nil)
        if conditions.is_a?(Hash)
          where_with_hash(conditions)
        else
          where_with_string(conditions, placeholders)
        end
      end

      # Turns on strongly consistent reads.
      #
      # By default reads are eventually consistent.
      #
      #   Post.where('size.gt' => 1000).consistent
      #
      # @return [Dynamoid::Criteria::Chain]
      def consistent
        @consistent_read = true
        self
      end

      # Returns all the records matching the criteria.
      #
      # Since +where+ and most of the other methods return a +Chain+
      # the only way to get a result as a collection is to call the +all+
      # method. It returns +Enumerator+ which could be used directly or
      # transformed into +Array+
      #
      #   Post.all                            # => Enumerator
      #   Post.where(links_count: 2).all      # => Enumerator
      #   Post.where(links_count: 2).all.to_a # => Array
      #
      # When the result set is too large DynamoDB divides it into separate
      # pages.  While an enumerator iterates over the result models each page
      # is loaded lazily. So even an extra large result set can be loaded and
      # processed with considerably small memory footprint and throughput
      # consumption.
      #
      # @return [Enumerator::Lazy]
      # @since 0.2.0
      def all
        records
      end

      # Returns the actual number of items in a table matching the criteria.
      #
      #   Post.where(links_count: 2).count
      #
      # Internally it uses either `Scan` or `Query` DynamoDB's operation so it
      # costs like all the matching items were read from a table.
      #
      # The only difference is that items are read by DynemoDB but not actually
      # loaded on the client side. DynamoDB returns only count of items after
      # filtering.
      #
      # @return [Integer]
      def count
        if @key_fields_detector.key_present?
          count_via_query
        else
          count_via_scan
        end
      end

      # Returns the first item matching the criteria.
      #
      #   Post.where(links_count: 2).first
      #
      # Applies `record_limit(1)` to ensure only a single record is fetched
      # when no non-key conditions are present and `scan_limit(1)` when no
      # conditions are present at all.
      #
      # If used without criteria it just returns the first item of some
      # arbitrary order.
      #
      #   Post.first
      #
      # @return [Model|nil]
      def first(*args)
        n = args.first || 1

        return dup.scan_limit(n).to_a.first(*args) if @where_conditions.empty?
        return super if @key_fields_detector.non_key_present?

        dup.record_limit(n).to_a.first(*args)
      end

      # Returns the last item matching the criteria.
      #
      #   Post.where(links_count: 2).last
      #
      # DynamoDB doesn't support ordering by some arbitrary attribute except a
      # sort key. So this method is mostly useful during development and
      # testing.
      #
      # If used without criteria it just returns the last item of some arbitrary order.
      #
      #   Post.last
      #
      # It isn't efficient from the performance point of view as far as it reads and
      # loads all the filtered items from DynamoDB.
      #
      # @return [Model|nil]
      def last
        all.to_a.last
      end

      # Deletes all the items matching the criteria.
      #
      #   Post.where(links_count: 2).delete_all
      #
      # If called without criteria then it deletes all the items in a table.
      #
      #   Post.delete_all
      #
      # It loads all the items either with +Scan+ or +Query+ operation and
      # deletes them in batch with +BatchWriteItem+ operation. +BatchWriteItem+
      # is limited by request size and items count so it's quite possible the
      # deletion will require several +BatchWriteItem+ calls.
      def delete_all
        ids = []
        ranges = []

        if @key_fields_detector.key_present?
          Dynamoid.adapter.query(source.table_name, query_key_conditions, query_non_key_conditions, query_options).flat_map { |i| i }.collect do |hash|
            ids << hash[source.hash_key.to_sym]
            ranges << hash[source.range_key.to_sym] if source.range_key
          end
        else
          Dynamoid.adapter.scan(source.table_name, scan_conditions, scan_options).flat_map { |i| i }.collect do |hash|
            ids << hash[source.hash_key.to_sym]
            ranges << hash[source.range_key.to_sym] if source.range_key
          end
        end

        Dynamoid.adapter.delete(source.table_name, ids, range_key: ranges.presence)
      end
      alias destroy_all delete_all

      # Set the record limit.
      #
      # The record limit is the limit of evaluated items returned by the
      # +Query+ or +Scan+. In other words it's how many items should be
      # returned in response.
      #
      #   Post.where(links_count: 2).record_limit(1000) # => 1000 models
      #   Post.record_limit(1000)                       # => 1000 models
      #
      # It could be very inefficient in terms of HTTP requests in pathological
      # cases. DynamoDB doesn't support out of the box the limits for items
      # count after filtering. So it's possible to make a lot of HTTP requests
      # to find items matching criteria and skip not matching. It means that
      # the cost (read capacity units) is unpredictable.
      #
      # Because of such issues with performance and cost it's mostly useful in
      # development and testing.
      #
      # When called without criteria it works like +scan_limit+.
      #
      # @return [Dynamoid::Criteria::Chain]
      def record_limit(limit)
        @record_limit = limit
        self
      end

      # Set the scan limit.
      #
      # The scan limit is the limit of records that DynamoDB will internally
      # read with +Query+ or +Scan+. It's different from the record limit as
      # with filtering DynamoDB may look at N scanned items but return 0
      # items if none passes the filter. So it can return less items than was
      # specified with the limit.
      #
      #   Post.where(links_count: 2).scan_limit(1000)   # => 850 models
      #   Post.scan_limit(1000)                         # => 1000 models
      #
      # By contrast with +record_limit+ the cost (read capacity units) and
      # performance is predictable.
      #
      # When called without criteria it works like +record_limit+.
      #
      # @return [Dynamoid::Criteria::Chain]
      def scan_limit(limit)
        @scan_limit = limit
        self
      end

      # Set the batch size.
      #
      # The batch size is a number of items which will be lazily loaded one by one.
      # When the batch size is set then items will be loaded batch by batch of
      # the specified size instead of relying on the default paging mechanism
      # of DynamoDB.
      #
      #   Post.where(links_count: 2).batch(1000).all.each do |post|
      #     # process a post
      #   end
      #
      # It's useful to limit memory usage or throughput consumption
      #
      # @return [Dynamoid::Criteria::Chain]
      def batch(batch_size)
        @batch_size = batch_size
        self
      end

      # Set the start item.
      #
      # When the start item is set the items will be loaded starting right
      # after the specified item.
      #
      #   Post.where(links_count: 2).start(post)
      #
      # It can be used to implement an own pagination mechanism.
      #
      #   Post.where(author_id: author_id).start(last_post).scan_limit(50)
      #
      # The specified start item will not be returned back in a result set.
      #
      # Actually it doesn't need all the item attributes to start - an item may
      # have only the primary key attributes (partition and sort key if it's
      # declared).
      #
      #   Post.where(links_count: 2).start(Post.new(id: id))
      #
      # It also supports a +Hash+ argument with the keys attributes - a
      # partition key and a sort key (if it's declared).
      #
      #   Post.where(links_count: 2).start(id: id)
      #
      # @return [Dynamoid::Criteria::Chain]
      def start(start)
        @start = start
        self
      end

      # Reverse the sort order.
      #
      # By default the sort order is ascending (by the sort key value). Set a
      # +false+ value to reverse the order.
      #
      #   Post.where(id: id, 'views_count.gt' => 1000).scan_index_forward(false)
      #
      # It works only for queries with a partition key condition e.g. +id:
      # 'some-id'+ which internally performs +Query+ operation.
      #
      # @return [Dynamoid::Criteria::Chain]
      def scan_index_forward(scan_index_forward)
        @scan_index_forward = scan_index_forward
        self
      end

      # Force the index name to use for queries.
      #
      # By default allows the library to select the most appropriate index.
      # Sometimes you have more than one index which will fulfill your query's
      # needs. When this case occurs you may want to force an order. This occurs
      # when you are searching by hash key, but not specifying a range key.
      #
      #  class Comment
      #    include Dynamoid::Document
      #
      #    table key: :post_id
      #    range_key :author_id
      #
      #    field :post_date, :datetime
      #
      #    global_secondary_index name: :time_sorted_comments, hash_key: :post_id, range_key: post_date, projected_attributes: :all
      #  end
      #
      #
      #   Comment.where(post_id: id).with_index(:time_sorted_comments).scan_index_forward(false)
      #
      # @return [Dynamoid::Criteria::Chain]
      def with_index(index_name)
        raise Dynamoid::Errors::InvalidIndex, "Unknown index #{index_name}" unless @source.find_index_by_name(index_name)

        @forced_index_name = index_name
        @key_fields_detector = KeyFieldsDetector.new(@where_conditions, @source, forced_index_name: index_name)
        self
      end

      # Allows to use the results of a search as an enumerable over the results
      # found.
      #
      #   Post.each do |post|
      #   end
      #
      #   Post.all.each do |post|
      #   end
      #
      #   Post.where(links_count: 2).each do |post|
      #   end
      #
      # It works similar to the +all+ method so results are loaded lazily.
      #
      # @since 0.2.0
      def each(&block)
        records.each(&block)
      end

      # Iterates over the pages returned by DynamoDB.
      #
      # DynamoDB has its own paging machanism and divides a large result set
      # into separate pages. The +find_by_pages+ method provides access to
      # these native DynamoDB pages.
      #
      # The pages are loaded lazily.
      #
      #   Post.where('views_count.gt' => 1000).find_by_pages do |posts, options|
      #     # process posts
      #   end
      #
      # It passes as block argument an +Array+ of models and a Hash with options.
      #
      # Options +Hash+ contains only one option +:last_evaluated_key+. The last
      # evaluated key is a Hash with key attributes of the last item processed by
      # DynamoDB. It can be used to resume querying using the +start+ method.
      #
      #   posts, options = Post.where('views_count.gt' => 1000).find_by_pages.first
      #   last_key = options[:last_evaluated_key]
      #
      #   # ...
      #
      #   Post.where('views_count.gt' => 1000).start(last_key).find_by_pages do |posts, options|
      #   end
      #
      # If it's called without a block then it returns an +Enumerator+.
      #
      #   enum = Post.where('views_count.gt' => 1000).find_by_pages
      #
      #   enum.each do |posts, options|
      #     # process posts
      #   end
      #
      # @return [Enumerator::Lazy]
      def find_by_pages(&block)
        pages.each(&block)
      end

      # Select only specified fields.
      #
      # It takes one or more field names and returns a collection of models with only
      # these fields set.
      #
      #   Post.where('views_count.gt' => 1000).project(:title)
      #   Post.where('views_count.gt' => 1000).project(:title, :created_at)
      #   Post.project(:id)
      #
      # It can be used to avoid loading large field values and to decrease a
      # memory footprint.
      #
      # @return [Dynamoid::Criteria::Chain]
      def project(*fields)
        @project = fields.map(&:to_sym)
        self
      end

      # Select only specified fields.
      #
      # It takes one or more field names and returns an array of either values
      # or arrays of values.
      #
      #   Post.pluck(:id)                   # => ['1', '2']
      #   Post.pluck(:title, :title)        # => [['1', 'Title #1'], ['2', 'Title#2']]
      #
      #   Post.where('views_count.gt' => 1000).pluck(:title)
      #
      # There are some differences between +pluck+ and +project+. +pluck+
      # - doesn't instantiate models
      # - it isn't chainable and returns +Array+ instead of +Chain+
      #
      # It deserializes values if a field type isn't supported by DynamoDB natively.
      #
      # It can be used to avoid loading large field values and to decrease a
      # memory footprint.
      #
      # @return [Array]
      def pluck(*args)
        fields = args.map(&:to_sym)

        # `project` has a side effect - it sets `@project` instance variable.
        # So use a duplicate to not pollute original chain.
        scope = dup
        scope.project(*fields)

        if fields.many?
          scope.items.map do |item|
            fields.map { |key| Undumping.undump_field(item[key], source.attributes[key]) }
          end.to_a
        else
          key = fields.first
          scope.items.map { |item| Undumping.undump_field(item[key], source.attributes[key]) }.to_a
        end
      end

      private

      def where_with_hash(conditions)
        detector = NonexistentFieldsDetector.new(conditions, @source)
        if detector.found?
          Dynamoid.logger.warn(detector.warning_message)
        end

        @where_conditions.update_with_hash(conditions.symbolize_keys)

        # we should re-initialize keys detector every time we change @where_conditions
        @key_fields_detector = KeyFieldsDetector.new(@where_conditions, @source, forced_index_name: @forced_index_name)

        self
      end

      def where_with_string(query, placeholders)
        @where_conditions.update_with_string(query, placeholders)

        # we should re-initialize keys detector every time we change @where_conditions
        @key_fields_detector = KeyFieldsDetector.new(@where_conditions, @source, forced_index_name: @forced_index_name)

        self
      end

      # The actual records referenced by the association.
      #
      # @return [Enumerator] an iterator of the found records.
      #
      # @since 0.2.0
      def records
        pages.lazy.flat_map { |items, _| items }
      end

      # Raw items like they are stored before type casting
      def items
        raw_pages.lazy.flat_map { |items, _| items }
      end
      protected :items

      # Arrays of records, sized based on the actual pages produced by DynamoDB
      #
      # @return [Enumerator] an iterator of the found records.
      #
      # @since 3.1.0
      def pages
        raw_pages.lazy.map do |items, options|
          models = items.map { |i| source.from_database(i) }
          models.each { |m| m.run_callbacks :find }
          [models, options]
        end.each
      end

      # Pages of items before type casting
      def raw_pages
        if @key_fields_detector.key_present?
          raw_pages_via_query
        else
          validate_scan_conditions
          raw_pages_via_scan
        end
      end

      # If the query matches an index, we'll query the associated table to find results.
      #
      # @return [Enumerator] an iterator of the found pages. An array of records
      #
      # @since 3.1.0
      def raw_pages_via_query
        Enumerator.new do |y|
          Dynamoid.adapter.query(source.table_name, query_key_conditions, query_non_key_conditions, query_options).each do |items, metadata|
            options = metadata.slice(:last_evaluated_key)

            y.yield items, options
          end
        end
      end

      # If the query does not match an index, we'll manually scan the associated table to find results.
      #
      # @return [Enumerator] an iterator of the found pages. An array of records
      #
      # @since 3.1.0
      def raw_pages_via_scan
        Enumerator.new do |y|
          Dynamoid.adapter.scan(source.table_name, scan_conditions, scan_options).each do |items, metadata|
            options = metadata.slice(:last_evaluated_key)

            y.yield items, options
          end
        end
      end

      def validate_scan_conditions
        raise Dynamoid::Errors::ScanProhibited if Dynamoid::Config.error_on_scan && !@where_conditions.empty?

        issue_scan_warning if Dynamoid::Config.warn_on_scan && !@where_conditions.empty?
      end

      def issue_scan_warning
        Dynamoid.logger.warn 'Queries without an index are forced to use scan and are generally much slower than indexed queries!'
        Dynamoid.logger.warn "You can index this query by adding index declaration to #{source.to_s.underscore}.rb:"
        Dynamoid.logger.warn "* global_secondary_index hash_key: 'some-name', range_key: 'some-another-name'"
        Dynamoid.logger.warn "* local_secondary_index range_key: 'some-name'"
        Dynamoid.logger.warn "Not indexed attributes: #{@where_conditions.keys.sort.collect { |name| ":#{name}" }.join(', ')}"
      end

      def count_via_query
        Dynamoid.adapter.query_count(source.table_name, query_key_conditions, query_non_key_conditions, query_options)
      end

      def count_via_scan
        Dynamoid.adapter.scan_count(source.table_name, scan_conditions, scan_options)
      end

      def field_condition(key, value_before_type_casting)
        name, operator = key.to_s.split('.')
        value = type_cast_condition_parameter(name, value_before_type_casting)
        operator ||= 'eq'

        unless operator.in? ALLOWED_FIELD_OPERATORS
          raise Dynamoid::Errors::Error, "Unsupported operator #{operator} in #{key}"
        end

        condition =
          case operator
            # NULL/NOT_NULL operators don't have parameters
            # So { null: true } means NULL check and { null: false } means NOT_NULL one
            # The same logic is used for { not_null: BOOL }
          when 'null'
            value ? [:null, nil] : [:not_null, nil]
          when 'not_null'
            value ? [:not_null, nil] : [:null, nil]
          else
            [operator.to_sym, value]
          end

        [name.to_sym, condition]
      end

      def query_key_conditions
        opts = {}

        # Add hash key
        # TODO: always have hash key in @where_conditions?
        _, condition = field_condition(@key_fields_detector.hash_key, @where_conditions[@key_fields_detector.hash_key])
        opts[@key_fields_detector.hash_key] = [condition]

        # Add range key
        if @key_fields_detector.range_key
          if @where_conditions[@key_fields_detector.range_key].present?
            _, condition = field_condition(@key_fields_detector.range_key, @where_conditions[@key_fields_detector.range_key])
            opts[@key_fields_detector.range_key] = [condition]
          end

          @where_conditions.keys.select { |k| k.to_s =~ /^#{@key_fields_detector.range_key}\./ }.each do |key|
            name, condition = field_condition(key, @where_conditions[key])
            opts[name] ||= []
            opts[name] << condition
          end
        end

        opts
      end

      def query_non_key_conditions
        hash_conditions = {}

        # Honor STI and :type field if it presents
        if @source.attributes.key?(@source.inheritance_field) &&
           @key_fields_detector.hash_key.to_sym != @source.inheritance_field.to_sym
          @where_conditions.update_with_hash(sti_condition)
        end

        # TODO: Separate key conditions and non-key conditions properly:
        #       only =, >, >=, <, <=, between and begins_with
        #       could be used for sort key in KeyConditionExpression
        keys = (@where_conditions.keys.map(&:to_sym) - [@key_fields_detector.hash_key.to_sym, @key_fields_detector.range_key.try(:to_sym)])
          .reject { |k, _| k.to_s =~ /^#{@key_fields_detector.range_key}\./ }
        keys.each do |key|
          name, condition = field_condition(key, @where_conditions[key])
          hash_conditions[name] ||= []
          hash_conditions[name] << condition
        end

        string_conditions = []
        @where_conditions.string_conditions.each do |query, placeholders|
          placeholders ||= {}
          string_conditions << [query, placeholders]
        end

        [hash_conditions] + string_conditions
      end

      # TODO: casting should be operator aware
      # e.g. for NULL operator value should be boolean
      # and isn't related to an attribute own type
      def type_cast_condition_parameter(key, value)
        return value if %i[array set].include?(source.attributes[key.to_sym][:type])

        if [true, false].include?(value) # Support argument for null/not_null operators
          value
        elsif !value.respond_to?(:to_ary)
          options = source.attributes[key.to_sym]
          value_casted = TypeCasting.cast_field(value, options)
          Dumping.dump_field(value_casted, options)
        else
          value.to_ary.map do |el|
            options = source.attributes[key.to_sym]
            value_casted = TypeCasting.cast_field(el, options)
            Dumping.dump_field(value_casted, options)
          end
        end
      end

      # Start key needs to be set up based on the index utilized
      # If using a secondary index then we must include the index's composite key
      # as well as the tables composite key.
      def start_key
        return @start if @start.is_a?(Hash)

        hash_key = @key_fields_detector.hash_key || source.hash_key
        range_key = @key_fields_detector.range_key || source.range_key

        key = {}
        key[hash_key] = type_cast_condition_parameter(hash_key, @start.send(hash_key))
        if range_key
          key[range_key] = type_cast_condition_parameter(range_key, @start.send(range_key))
        end
        # Add table composite keys if they differ from secondary index used composite key
        if hash_key != source.hash_key
          key[source.hash_key] = type_cast_condition_parameter(source.hash_key, @start.hash_key)
        end
        if source.range_key && range_key != source.range_key
          key[source.range_key] = type_cast_condition_parameter(source.range_key, @start.range_value)
        end
        key
      end

      def query_options
        opts = {}
        # Don't specify select = ALL_ATTRIBUTES option explicitly because it's
        # already a default value of Select statement. Explicite Select value
        # conflicts with AttributesToGet statement (project option).
        opts[:index_name] = @key_fields_detector.index_name if @key_fields_detector.index_name
        opts[:record_limit] = @record_limit if @record_limit
        opts[:scan_limit] = @scan_limit if @scan_limit
        opts[:batch_size] = @batch_size if @batch_size
        opts[:exclusive_start_key] = start_key if @start
        opts[:scan_index_forward] = @scan_index_forward
        opts[:project] = @project
        opts[:consistent_read] = true if @consistent_read
        opts
      end

      def scan_conditions
        # Honor STI and :type field if it presents
        if sti_condition
          @where_conditions.update_with_hash(sti_condition)
        end

        hash_conditions = {}
        hash_conditions.tap do |opts|
          @where_conditions.keys.map(&:to_sym).each do |key|
            name, condition = field_condition(key, @where_conditions[key])
            opts[name] ||= []
            opts[name] << condition
          end
        end

        string_conditions = []
        @where_conditions.string_conditions.each do |query, placeholders|
          placeholders ||= {}
          string_conditions << [query, placeholders]
        end

        [hash_conditions] + string_conditions
      end

      def scan_options
        opts = {}
        opts[:index_name] = @key_fields_detector.index_name if @key_fields_detector.index_name
        opts[:record_limit] = @record_limit if @record_limit
        opts[:scan_limit] = @scan_limit if @scan_limit
        opts[:batch_size] = @batch_size if @batch_size
        opts[:exclusive_start_key] = start_key if @start
        opts[:consistent_read] = true if @consistent_read
        opts[:project] = @project
        opts
      end

      # TODO: return Array, not String
      def sti_condition
        condition = {}
        type = @source.inheritance_field

        if @source.attributes.key?(type) && !@source.abstract_class?
          sti_names = @source.deep_subclasses.map(&:sti_name) << @source.sti_name
          condition[:"#{type}.in"] = sti_names
        end

        condition
      end
    end
  end
end
