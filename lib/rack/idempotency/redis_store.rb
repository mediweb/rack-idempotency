module Rack
  class Idempotency
    # Stores idempotency information in Redis store.
    class RedisStore
      def initialize(redis_options={})
        @store = Redis.new(redis_options)
      end

      def read(id)
        @store.get(id)
      end

      def write(id, value)
        @store.set(id, value)
      end

      def lock(id, &block)
        s = Redis::Semaphore.new(id, :redis => @store)
        s.lock(0) do
          block.call
        end
      end

      private

      attr_reader :store
    end
  end
end
