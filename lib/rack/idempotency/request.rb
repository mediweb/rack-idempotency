require "rack"
require "rack/request"
require "backports/2.4.0/string/match" if RUBY_VERSION < "2.4.0"

module Rack
  class Idempotency
    class Request < Rack::Request
      def idempotency_key
        key = get_header("HTTP_IDEMPOTENCY_KEY")

        unless key.nil? || key.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)
          raise InsecureKeyError.new(env), 'Idempotency-Key must be a valid UUID'
        end
        key
      end
      if Rack.release < "2.0.0"
        def get_header(name)
          @env[name]
        end
      end
    end
  end
end
