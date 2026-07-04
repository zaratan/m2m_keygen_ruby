# Migrating from v1 to v2 (`m2m-keygen/2`)

v2 replaces the signature scheme. A v1 signature does not validate under v2 and
vice-versa, so **the sender and the receiver must be upgraded together** — plan a
coordinated deploy (both ends share the secret; upgrade them in lockstep). If a
TypeScript counterpart signs or verifies these requests, it must move to v2 too,
following [SPEC.md](SPEC.md).

## What changed and why

v1 signed `"#{VERB}#{path}#{params_as_k=v}"`, which collided on unescaped
delimiters, dropped empty values, confused types, and had no replay protection.
v2 signs the request's **wire bytes** (method, path, byte-order-sorted query, raw
body) length-prefixed, plus a **signed expiry and nonce**. See [SPEC.md](SPEC.md)
for the full format.

## API changes

| v1 | v2 |
|----|----|
| `Signature#sign(params:, verb:, path:)` | `Signature#sign(verb:, path:, expiry:, nonce:, query: '', body: '')` |
| `Signature#validate(params:, verb:, path:, signature:)` | `Signature#validate(signature:, verb:, path:, expiry:, nonce:, query: '', body: '')` |
| `ParamsEncoder` | removed (internal `Canonicalizer`) |
| `RackValidator.new(secret, algorithm:, header_name:)` | `RackValidator.new(secret, nonce_store:, algorithm:, header_name:, window:, expiry_header:, nonce_header:)` |
| expiry passed as a request param | expiry sent in the `X-M2M-Expiry` header (signed) |
| — | nonce sent in the `X-M2M-Nonce` header (signed) |
| — | `RequestSigner` client helper |

## On the sender

Replace hand-built signatures with `RequestSigner`, which generates the nonce and
expiry and returns the headers to send:

```ruby
signer = M2mKeygen::RequestSigner.new(secret)
signed = signer.sign_request(verb: "GET", path: "/orders", params: { "since" => "2026-01-01" })

# signed.query   => the query string to send
# signed.headers => { "X-Signature" => ..., "X-M2M-Expiry" => ..., "X-M2M-Nonce" => ... }
```

For a body request, pass `body:` (the exact bytes you will send).

## On the receiver

`RackValidator` now **requires** a nonce store — pick one explicitly:

```ruby
# Single-process / development:
M2mKeygen::RackValidator.new(secret, nonce_store: M2mKeygen::NonceStore::Memory.new)

# Multi-worker / multi-host production: use a shared store
# (see examples/nonce_store/redis.rb and postgres.rb):
M2mKeygen::RackValidator.new(secret, nonce_store: RedisNonceStore.new(Redis.new))

# Expiry-only, no replay protection — a deliberate, visible opt-out:
M2mKeygen::RackValidator.new(secret, nonce_store: M2mKeygen::NonceStore::Disabled.new)
```

`validate(request)` still returns `true`/`false`; it now also rejects a replayed
or missing nonce (unless the store is `Disabled`).

## Checklist

1. Upgrade the gem (and the TS lib, if any) on **both** ends.
2. Sender: switch to `RequestSigner`; send the three headers and the returned query.
3. Receiver: pass a `nonce_store:`; expect expiry/nonce in headers.
4. Deploy sender and receiver together (a v1 sender against a v2 receiver, or the
   reverse, will fail every signature).
