# typed: strict

module M2mKeygen
  module NonceStore
    # Explicit, greppable opt-out: `add` always succeeds, so replay protection
    # falls back to expiry-only. See docs/ for when that risk is acceptable.
    class Disabled
      include NonceStore
      extend T::Sig

      # rubocop:disable Lint/UnusedMethodArgument -- interface method, args unused here
      sig { override.params(nonce: String, ttl: Integer).returns(T::Boolean) }
      def add(nonce, ttl:)
        true
      end
      # rubocop:enable Lint/UnusedMethodArgument
    end
  end
end
