require "spec_helper"

RSpec.describe Rack::Idempotency do
  let(:app) { lambda { |_| [200, { "Content-Type" => "text/plain" }, [SecureRandom.uuid]] } }
  let(:middleware) { Rack::Idempotency.new(app, store: Rack::Idempotency::MemoryStore.new) }
  let(:request) { Rack::MockRequest.new(middleware) }
  let(:key) { SecureRandom.uuid }

  it "has a version number" do
    expect(Rack::Idempotency::VERSION).not_to be nil
  end

  context "without an idempotency key" do
    subject { request.get("/").body }

    it { is_expected.to_not be_nil }
  end

  context "with insecure idempotency key" do
    subject { -> { request.get("/", "HTTP_IDEMPOTENCY_KEY" => 'x') } }

    it { is_expected.to raise_error }
  end

  context "with an idempotency key" do
    subject { request.get("/", "HTTP_IDEMPOTENCY_KEY" => key).body }

    context "with a successful request" do
      context "on first request" do
        it { is_expected.to_not be_nil }
      end

      context "on second request" do
        let(:original) { request.get("/", "HTTP_IDEMPOTENCY_KEY" => key).body }

        it { is_expected.to eq(original) }
      end

      context "on different request" do
        let(:different) { request.get("/", "HTTP_IDEMPOTENCY_KEY" => SecureRandom.uuid).body }

        it { is_expected.to_not eq(different) }
      end
    end

    context "with a failed request" do
      let(:app) { lambda { |_| [500, { "Content-Type" => "text/plain" }, [SecureRandom.uuid]] } }

      context "on first request" do
        it { is_expected.to_not be_nil }
      end

      context "on second request" do
        let(:original) { request.get("/", "HTTP_IDEMPOTENCY_KEY" => key).body }

        it { is_expected.to_not eq(original) }
      end
    end
  end

  context "with redis store" do
    let(:middleware) { Rack::Idempotency.new(app, store: Rack::Idempotency::RedisStore.new) }
    let(:storage_key) { "rack:idempotency:" + key }

    context "without an idempotency key" do
      subject { request.get("/").body }

      it { is_expected.to_not be_empty }
    end

    context "with an idempotency key" do
      let(:get_request) { request.get("/", "HTTP_IDEMPOTENCY_KEY" => key) }

      context "with a successful request" do
        subject { get_request.body }
        it { is_expected.to_not be_empty }
      end

      context "with concurrent request with same key" do
        subject { get_request }
        it do
          store = Rack::Idempotency::RedisStore.new
          store.lock(storage_key) do
            expect(subject.body).to be_empty
            expect(subject.headers).to eq({"X-Accel-Redirect" => "/drop", "Content-Length" => "0"})
          end
        end
      end

      context "with concurrent request with different key" do
        subject { get_request }
        let(:different_key) { SecureRandom.uuid }

        it do
          store = Rack::Idempotency::RedisStore.new
          store.lock(different_key) do
            expect(subject.body).to_not be_empty
            expect(subject.headers).to eq("Content-Type"=>"text/plain", "Content-Length"=>"36")
          end
        end
      end
    end
  end
end
