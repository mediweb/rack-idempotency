module Rack
  class Idempotency
    class RequestStorage
      def initialize(store, request)
        @store   = store
        @request = request
      end

      def read
        stored = store.read(storage_key)
        JSON.parse(stored) if stored
      end

      def write(response)
        store.write(storage_key, response.to_json)
      end

      def key
        storage_key
      end

      private

      attr_reader :request
      attr_reader :store

      def storage_key
        "rack:idempotency:" + request.idempotency_key
      end
    end
  end
end
