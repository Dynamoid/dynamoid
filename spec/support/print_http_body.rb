# frozen_string_literal: true

class PrintHttpBody < Seahorse::Client::Plugin
  class << self
    attr_reader :logged_requests
    attr_accessor :enabled
  end

  @logged_requests = [] # rubocop:disable ThreadSafety/MutableClassInstanceVariable

  class Handler < Seahorse::Client::Handler
    def call(context)
      if PrintHttpBody.enabled
        target_header = context.http_request.headers.to_h['x-amz-target']
        operation_name = target_header.split('.').last

        body = context.http_request.body.read
        context.http_request.body.rewind

        request = { operation_name: operation_name, body: JSON.parse(body) }
        PrintHttpBody.logged_requests << request
      end

      @handler.call(context)
    end
  end

  def add_handlers(handlers, _cfg)
    handlers.add(Handler, step: :sign, priority: 99)
  end
end

Aws::DynamoDB::Client.add_plugin(PrintHttpBody)
