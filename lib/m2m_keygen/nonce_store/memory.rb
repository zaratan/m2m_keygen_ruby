# typed: strict

module M2mKeygen
  module NonceStore
    # In-process nonce store backed by a Mutex-guarded Hash.
    #
    # ⚠️ SINGLE-PROCESS ONLY. This store lives in this Ruby process' memory.
    # As soon as your service runs more than one process — multiple Puma/Unicorn
    # workers, multiple hosts, a restart between two requests — each process
    # holds its own independent set of seen nonces, so replay protection becomes
    # PARTIAL: a nonce recorded by worker A is invisible to worker B, which will
    # happily accept it again. Use this only for single-process deployments or
    # local development. For multi-worker/multi-host production, back
    # `nonce_store:` with a store shared across processes (e.g. Redis or
    # Postgres) — see the reference implementations under `examples/nonce_store/`.
    class Memory
      include NonceStore
      extend T::Sig

      DEFAULT_MAX_SIZE = 100_000

      sig { params(max_size: Integer).void }
      def initialize(max_size: DEFAULT_MAX_SIZE)
        @max_size = T.let(max_size, Integer)
        @mutex = T.let(Mutex.new, Mutex)
        @expirations_by_nonce = T.let({}, T::Hash[String, Float])
      end

      sig { override.params(nonce: String, ttl: Integer).returns(T::Boolean) }
      def add(nonce, ttl:)
        @mutex.synchronize do
          purge_expired
          next false if @expirations_by_nonce.key?(nonce)

          evict_soonest_to_expire if at_capacity?
          @expirations_by_nonce[nonce] = Time.now.to_f + ttl
          true
        end
      end

      private

      sig { void }
      def purge_expired
        now = Time.now.to_f
        @expirations_by_nonce.delete_if do |_nonce, expires_at|
          expires_at <= now
        end
      end

      sig { returns(T::Boolean) }
      def at_capacity?
        @expirations_by_nonce.size >= @max_size
      end

      sig { void }
      def evict_soonest_to_expire
        soonest, =
          @expirations_by_nonce.min_by { |_nonce, expires_at| expires_at }
        @expirations_by_nonce.delete(soonest) if soonest
      end
    end
  end
end
