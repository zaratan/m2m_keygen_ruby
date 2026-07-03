# typed: strict

require 'openssl'
require 'json'

module M2mKeygen
  class Signature
    extend T::Sig

    sig { returns(String) }
    attr_reader :algorithm

    sig { params(secret: String, algorithm: String).void }
    def initialize(secret, algorithm: 'sha512')
      @secret = T.let(secret, String)
      @algorithm = T.let(algorithm, String)
      OpenSSL::HMAC.hexdigest(@algorithm, @secret, '')
    end

    sig { returns(String) }
    def inspect
      "#<#{self.class.name} algorithm=#{@algorithm.inspect}>"
    end

    sig do
      params(
        params: Types::ParamsType,
        verb: T.any(String, Symbol),
        path: String,
      ).returns(String)
    end
    def sign(params:, verb:, path:)
      OpenSSL::HMAC.hexdigest(
        @algorithm,
        @secret,
        "#{verb.to_s.upcase}#{path}#{ParamsEncoder.new(params).encode}",
      )
    end

    sig do
      params(
        params: Types::ParamsType,
        verb: T.any(String, Symbol),
        path: String,
        signature: String,
      ).returns(T::Boolean)
    end
    def validate(params:, verb:, path:, signature:)
      OpenSSL.fixed_length_secure_compare(
        sign(params: params, verb: verb, path: path),
        signature,
      )
    rescue StandardError
      false
    end
  end
end
