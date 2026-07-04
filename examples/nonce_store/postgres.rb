# typed: false
# frozen_string_literal: true

# Reference M2mKeygen::NonceStore backed by PostgreSQL. Requires the `pg` gem
# and this table:
#
#   CREATE TABLE m2m_nonces (
#     nonce      text        PRIMARY KEY,
#     expires_at timestamptz NOT NULL
#   );
#   CREATE INDEX m2m_nonces_expires_at_idx ON m2m_nonces (expires_at);
#
#   store = PostgresNonceStore.new(PG.connect(ENV['DATABASE_URL']))
#   RackValidator.new(secret, nonce_store: store)
#
# Like Redis, this store is shared across processes. `INSERT ... ON CONFLICT
# DO NOTHING RETURNING` is the atomic check-and-set: a row is returned only when
# this call actually inserted the nonce. Expired rows are inert (a fresh request
# always carries a fresh random nonce), but should be reclaimed periodically —
# call `#purge_expired` from a cron or background job.
class PostgresNonceStore
  def initialize(connection)
    @connection = connection
  end

  def add(nonce, ttl:)
    result =
      @connection.exec_params(
        'INSERT INTO m2m_nonces (nonce, expires_at) ' \
          'VALUES ($1, now() + make_interval(secs => $2::int)) ' \
          'ON CONFLICT (nonce) DO NOTHING RETURNING nonce',
        [nonce, ttl],
      )
    result.ntuples.positive?
  end

  def purge_expired
    @connection.exec('DELETE FROM m2m_nonces WHERE expires_at < now()')
  end
end
