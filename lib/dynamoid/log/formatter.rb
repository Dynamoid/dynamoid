# frozen_string_literal: true

module Dynamoid
  module Log
    # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/Log/Formatter.html
    # https://docs.aws.amazon.com/sdk-for-ruby/v2/api/Seahorse/Client/Response.html
    # https://aws.amazon.com/ru/blogs/developer/logging-requests/
    module Formatter
      class Debug
        def format(response)
          bold = "\x1b[1m"
          color = "\x1b[34m"
          reset = "\x1b[0m"

          [
            response.context.operation.name,
            "#{bold}#{color}\nRequest:\n#{reset}#{bold}",
            JSON.pretty_generate(JSON.parse(response.context.http_request.body.string)),
            "#{bold}#{color}\nResponse:\n#{reset}#{bold}",
            JSON.pretty_generate(JSON.parse(response.context.http_response.body.string)),
            reset
          ].join("\n")
        end
      end

      class Compact
        def format(response)
          bold = "\x1b[1m"
          reset = "\x1b[0m"

          [
            response.context.operation.name,
            bold,
            response.context.http_request.body.string,
            reset
          ].join(' ')
        end
      end
    end
  end
end
