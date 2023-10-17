# frozen_string_literal: true

module Dynamoid
  # @private
  module AdapterPlugin
    class AwsSdkV3

      class PrintHttpBody < Seahorse::Client::Plugin
        class Handler < Seahorse::Client::Handler
          def call(context)
            puts "HTTP REQUEST BODY:"
            puts context.http_request.body.read
            context.http_request.body.rewind
            @handler.call(context)
          end
        end

        def add_handlers(handlers, cfg)
          handlers.add(Handler, step: :sign, priority: 99)
        end
      end
    end
  end
end
