# typed: strict

module M2mKeygen
  # `add` MUST be atomic (check-and-set in one step): a separate seen?/record
  # pair would be a TOCTOU race.
  module NonceStore
    extend T::Sig
    extend T::Helpers
    include Kernel

    interface!

    # Returns true if newly recorded, false if already seen (replay).
    sig { abstract.params(nonce: String, ttl: Integer).returns(T::Boolean) }
    def add(nonce, ttl:)
    end
  end
end
