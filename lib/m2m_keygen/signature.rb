# typed: strict

require 'openssl'

module M2mKeygen
  class Signature
    extend T::Sig

    sig { returns(String) }
    attr_reader :algorithm

    sig { params(secret: String, algorithm: String).void }
    def initialize(secret, algorithm: 'sha512')
      @secret = T.let(secret, String)
      @algorithm = T.let(algorithm, String)
      # Fail fast on an unsupported algorithm (OpenSSL's error class varies).
      OpenSSL::HMAC.hexdigest(@algorithm, @secret, '')
    rescue StandardError => e
      raise Error,
            "Unsupported HMAC algorithm #{algorithm.inspect}: #{e.message}"
    end

    sig { returns(String) }
    def inspect
      "#<#{self.class.name} algorithm=#{@algorithm.inspect}>"
    end

    sig do
      params(
        verb: String,
        path: String,
        expiry: Integer,
        nonce: String,
        query: String,
        body: String,
      ).returns(String)
    end
    def sign(verb:, path:, expiry:, nonce:, query: '', body: '')
      OpenSSL::HMAC.hexdigest(
        @algorithm,
        @secret,
        Canonicalizer.canonical(
          verb: verb,
          path: path,
          expiry: expiry,
          nonce: nonce,
          query: query,
          body: body,
        ),
      )
    end

    sig do
      params(
        signature: String,
        verb: String,
        path: String,
        expiry: Integer,
        nonce: String,
        query: String,
        body: String,
      ).returns(T::Boolean)
    end
    def validate(signature:, verb:, path:, expiry:, nonce:, query: '', body: '')
      OpenSSL.fixed_length_secure_compare(
        sign(
          verb: verb,
          path: path,
          expiry: expiry,
          nonce: nonce,
          query: query,
          body: body,
        ),
        signature,
      )
    rescue StandardError
      false
    end
  end
end
