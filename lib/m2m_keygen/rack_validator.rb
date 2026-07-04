# typed: strict

require 'rack'

module M2mKeygen
  class RackValidator
    extend T::Sig

    ACCEPTED_VERSIONS = T.let([2].freeze, T::Array[Integer])

    DEFAULT_WINDOW_SECONDS = 120
    NONCE_TTL_MARGIN_SECONDS = 5

    sig { returns(Signature) }
    attr_reader :signature

    sig { returns(String) }
    attr_reader :header_name

    sig do
      params(
        secret: String,
        nonce_store: NonceStore,
        algorithm: String,
        header_name: String,
        window: Integer,
        expiry_header: String,
        nonce_header: String,
      ).void
    end
    def initialize(
      secret,
      nonce_store:,
      algorithm: 'sha512',
      header_name: 'X-Signature',
      window: DEFAULT_WINDOW_SECONDS,
      expiry_header: 'X-M2M-Expiry',
      nonce_header: 'X-M2M-Nonce'
    )
      @signature = T.let(Signature.new(secret, algorithm: algorithm), Signature)
      @nonce_store = T.let(nonce_store, NonceStore)
      @window = T.let(window, Integer)
      @header_name = T.let(env_key_for(header_name), String)
      @expiry_header = T.let(env_key_for(expiry_header), String)
      @nonce_header = T.let(env_key_for(nonce_header), String)
    end

    sig { params(req: T.untyped).returns(T::Boolean) }
    def validate(req)
      request = Rack::Request.new(req.env)
      nonce = request.env[@nonce_header].to_s
      return false if nonce.empty? && nonce_required?

      expiry = request.env[@expiry_header].to_i
      body = request.body.read.to_s
      request.body.rewind

      valid_signature =
        @signature.validate(
          signature: request.env[@header_name].to_s,
          verb: request.request_method || 'GET',
          path: request.path || '/',
          expiry: expiry,
          nonce: nonce,
          query: request.query_string || '',
          body: body,
        )

      !!(
        valid_signature && expiry_within_window?(expiry) &&
          @nonce_store.add(nonce, ttl: nonce_ttl(expiry))
      )
    end

    private

    sig { returns(T::Boolean) }
    def nonce_required?
      !@nonce_store.is_a?(NonceStore::Disabled)
    end

    sig { params(expiry: Integer).returns(T::Boolean) }
    def expiry_within_window?(expiry)
      now = Time.now.to_i
      now < expiry && expiry < now + @window
    end

    sig { params(expiry: Integer).returns(Integer) }
    def nonce_ttl(expiry)
      expiry - Time.now.to_i + NONCE_TTL_MARGIN_SECONDS
    end

    sig { params(name: String).returns(String) }
    def env_key_for(name)
      "HTTP_#{name.tr('-', '_').upcase}"
    end
  end
end
