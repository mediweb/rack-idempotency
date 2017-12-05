require "json"

require "rack/idempotency/version"

require "rack/idempotency/errors"
require "rack/idempotency/memory_store"
require "rack/idempotency/redis_store"
require "rack/idempotency/null_store"
require "rack/idempotency/request"
require "rack/idempotency/request_storage"
require "rack/idempotency/response"

module Rack
  # Rack middleware for ensuring mutating endpoints are called at most once.
  #
  # Any request with an `Idempotency-Key` header will store its response in
  # the given cache.  When the client retries, it will get the previously
  # cached response.
  class Idempotency
    def initialize(app, store: NullStore.new)
      @app     = app
      @store   = store
      if @store.class.to_s == "Rack::Idempotency::RedisStore"
        @mutex_mode = true
        @cache_errors = true
      end
    end

    def call(env)
      request = Request.new(env.dup.freeze)
      read_response(request, env).to_a
    end

    def read_response(request, env)
      if request.idempotency_key
        @storage = RequestStorage.new(@store, request)
        @storage.read || store_response(env)
      else
        Response.new(*@app.call(env))
      end
    end

    private

    def fetch_and_cache(env)
      response = Response.new(*@app.call(env))
      @storage.write(response) if @cache_errors || response.success?
      response
    end

    def store_response(env)
      if @mutex_mode
        resp = nil
        @store.lock(@storage.key) do
          resp = fetch_and_cache(env)
        end
        unless resp
          resp = Response.new(444, {"X-Accel-Redirect" => "/drop"}, [""])
        end
        resp
      else
        fetch_and_cache(env)
      end
    end
  end
end
