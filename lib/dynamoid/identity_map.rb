module Dynamoid
  module IdentityMap
    extend ActiveSupport::Concern

    def self.clear
      models.each { |m| m.identity_map.clear }
    end

    def self.models
      Dynamoid::Config.included_models
    end

    module ClassMethods
      def identity_map
        @identity_map ||= {}
      end

      def from_database(attrs = {})
        return super if identity_map_off?

        key = identity_map_key(attrs)
        document = identity_map[key]

        if document.nil?
          document = super
          identity_map[key] = document
        else
          document.load(attrs)
        end

        document
      end

      def find_by_id(id, options = {})
        return super if identity_map_off?

        key = id.to_s

        if range_key = options[:range_key]
          key += "::#{range_key}"
        end

        if identity_map[key]
          identity_map[key]
        else
          super
        end
      end

      def identity_map_key(attrs)
        key = attrs[hash_key].to_s
        if range_key
          key += "::#{attrs[range_key]}"
        end
        key
      end

      def identity_map_on?
        Dynamoid::Config.identity_map
      end

      def identity_map_off?
        !identity_map_on?
      end
    end

    def identity_map
      self.class.identity_map
    end

    def save(*args)
      return super if self.class.identity_map_off?

      if result = super
        identity_map[identity_map_key] = self
      end
      result
    end

    def delete
      return super if self.class.identity_map_off?

      identity_map.delete(identity_map_key)
      super
    end


    def identity_map_key
      key = hash_key.to_s
      if self.class.range_key
        key += "::#{range_value}"
      end
      key
    end
  end
end
