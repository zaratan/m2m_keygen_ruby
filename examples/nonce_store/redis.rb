# typed: false
# frozen_string_literal: true

# Reference M2mKeygen::NonceStore backed by Redis. Requires the `redis` gem.
#
#   store = RedisNonceStore.new(Redis.new)
#   RackValidator.new(secret, nonce_store: store)
#
# Redis is a good fit for multi-worker/multi-host production: the store is
# shared across all processes, and `SET ... NX PX` gives the atomic
# check-and-set the NonceStore contract requires, with the TTL handled natively
# (no purge to run).
class RedisNonceStore
  def initialize(redis, prefix: 'm2m:nonce:')
    @redis = redis
    @prefix = prefix
  end

  # Returns true only if the key did not exist (nonce is new); false on replay.
  def add(nonce, ttl:)
    @redis.set("#{@prefix}#{nonce}", '1', nx: true, px: ttl * 1000) == true
  end
end
