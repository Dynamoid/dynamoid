module Dynamoid
  module Tasks
    module Database
      extend self

      def create_tables
        puts 'create tables'
      end

      # Is the DynamoDB reachable?
      def ping
        adapter = Dynamoid::Adapter.new
        begin
          adapter.adapter.connect!
          true
        rescue
          false
        end
      end

    end
  end
end
