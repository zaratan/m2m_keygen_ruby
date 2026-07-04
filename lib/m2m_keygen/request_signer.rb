# typed: strict

require 'rack'
require 'securerandom'

module M2mKeygen
  class RequestSigner
    extend T::Sig

    DEFAULT_EXPIRY_TTL_SECONDS = 90
    NONCE_BYTES = 16

    sig do
      params(
        secret: String,
        algorithm: String,
        header_name: String,
        expiry_header: String,
        nonce_header: String,
      ).void
    end
    def initialize(
      secret,
      algorithm: 'sha512',
      header_name: 'X-Signature',
      expiry_header: 'X-M2M-Expiry',
      nonce_header: 'X-M2M-Nonce'
    )
      @signature = T.let(Signature.new(secret, algorithm: algorithm), Signature)
      @header_name = T.let(header_name, String)
      @expiry_header = T.let(expiry_header, String)
      @nonce_header = T.let(nonce_header, String)
    end

    sig do
      params(
        verb: String,
        path: String,
        params: Types::ParamsType,
        body: String,
        expiry: T.nilable(Integer),
        nonce: T.nilable(String),
      ).returns(SignedRequest)
    end
    def sign_request(
      verb:,
      path:,
      params: {},
      body: '',
      expiry: nil,
      nonce: nil
    )
      resolved_nonce = nonce || SecureRandom.hex(NONCE_BYTES)
      resolved_expiry = expiry || (Time.now.to_i + DEFAULT_EXPIRY_TTL_SECONDS)
      query = build_query(params)

      signature =
        @signature.sign(
          verb: verb,
          path: path,
          expiry: resolved_expiry,
          nonce: resolved_nonce,
          query: query,
          body: body,
        )

      SignedRequest.new(
        headers: {
          @header_name => signature,
          @expiry_header => resolved_expiry.to_s,
          @nonce_header => resolved_nonce,
        },
        query: query,
      )
    end

    private

    sig { params(params: Types::ParamsType).returns(String) }
    def build_query(params)
      return '' if params.empty?

      Rack::Utils.build_query(stringify_values(params))
    end

    sig do
      params(params: Types::ParamsType).returns(T::Hash[String, T.untyped])
    end
    def stringify_values(params)
      params
        .transform_keys(&:to_s)
        .transform_values { |value| stringify(value) }
    end

    sig do
      params(value: Types::ParamsValueType).returns(
        T.any(String, T::Array[String]),
      )
    end
    def stringify(value)
      if value.is_a?(Array)
        return value.map { |element| stringify_scalar(element) }
      end

      stringify_scalar(value)
    end

    sig { params(value: Types::ParamsScalarType).returns(String) }
    def stringify_scalar(value)
      if value.is_a?(Float) && !value.finite?
        raise CanonicalizationError,
              "Non-finite float values cannot be signed (NaN/Infinity): #{value.inspect}"
      end

      value.to_s
    end
  end
end
