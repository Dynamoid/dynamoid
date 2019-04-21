# frozen_string_literal: true

module Dynamoid
  module AdapterPlugin
    class AwsSdkV3
      class UntilPastTableStatus
        attr_reader :table_name, :status

        def initialize(table_name, status = :creating)
          @table_name = table_name
          @status = status
        end

        def call
          counter = 0
          resp = nil
          begin
            check = { again: true }
            while check[:again]
              sleep Dynamoid::Config.sync_retry_wait_seconds
              resp = client.describe_table(table_name: table_name)
              check = check_table_status?(counter, resp, status)
              Dynamoid.logger.info "Checked table status for #{table_name} (check #{check.inspect})"
              counter += 1
            end
          # If you issue a DescribeTable request immediately after a CreateTable
          #   request, DynamoDB might return a ResourceNotFoundException.
          # This is because DescribeTable uses an eventually consistent query,
          #   and the metadata for your table might not be available at that moment.
          # Wait for a few seconds, and then try the DescribeTable request again.
          # See: http://docs.aws.amazon.com/sdkforruby/api/Aws/DynamoDB/Client.html#describe_table-instance_method
          rescue Aws::DynamoDB::Errors::ResourceNotFoundException => e
            case status
            when :creating then
              if counter >= Dynamoid::Config.sync_retry_max_times
                Dynamoid.logger.warn "Waiting on table metadata for #{table_name} (check #{counter})"
                retry # start over at first line of begin, does not reset counter
              else
                Dynamoid.logger.error "Exhausted max retries (Dynamoid::Config.sync_retry_max_times) waiting on table metadata for #{table_name} (check #{counter})"
                raise e
              end
            else
              # When deleting a table, "not found" is the goal.
              Dynamoid.logger.info "Checked table status for #{table_name}: Not Found (check #{check.inspect})"
            end
          end
        end

        private

        def check_table_status?(counter, resp, expect_status)
          status = PARSE_TABLE_STATUS.call(resp)
          again = counter < Dynamoid::Config.sync_retry_max_times &&
                  status == TABLE_STATUSES[expect_status]
          { again: again, status: status, counter: counter }
        end
      end
    end
  end
end
