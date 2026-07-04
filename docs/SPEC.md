# m2m-keygen/2 — signature scheme specification

This is the language-agnostic contract for the `m2m-keygen/2` request signing
scheme. Any implementation (this Ruby gem, its TypeScript sibling, or any other)
that produces or verifies signatures MUST follow it byte-for-byte. The
[golden vectors](#golden-vectors) at the end are the conformance test set.

## Overview

A sender signs an HTTP request with an HMAC keyed by a shared secret and sends
the signature (plus an expiry and a nonce) in headers. The receiver rebuilds the
same signing input from the request it received and recomputes the HMAC. If they
match (constant-time compare) and the expiry/nonce checks pass, the request is
authentic and fresh.

The signature commits to the request's **wire bytes** (method, path, the query
string, and the raw body) rather than to a re-parsed data structure. This is
what makes the scheme unambiguous and portable: there is no cross-language
serialization to agree on — each side signs the bytes as they appear on the
wire.

## Canonical string

The signed message is a single byte string built by concatenating these seven
components, in this exact order:

| # | Component        | Value                                                        |
|---|------------------|--------------------------------------------------------------|
| 1 | scheme           | the literal ASCII string `m2m-keygen/2`                      |
| 2 | verb             | the HTTP method, uppercased (ASCII)                          |
| 3 | path             | the request path, percent-decoded (as `Rack::Request#path` / `new URL().pathname` give it) |
| 4 | expiry           | the expiry, an integer Unix timestamp (seconds), as its decimal string |
| 5 | nonce            | the nonce string                                             |
| 6 | canonical_query  | the canonicalized query string (see below)                  |
| 7 | body             | the raw request body bytes, exactly as sent                 |

Each component is **length-prefixed** with its **UTF-8 byte length** and a colon,
then all seven are concatenated with no separator:

```
canonical = ""
for component in components:
    bytes      = utf8_bytes(component)      # for the body: the raw bytes as-is
    canonical += ascii(bytes.length) + ":" + bytes
signature = hex( HMAC(algorithm, secret, canonical) )
```

Length-prefixing makes every field boundary unambiguous: no `&`, `=`, `/` or any
other byte in a value can be mistaken for a delimiter, and no field can "borrow"
bytes from its neighbour.

- `bytes.length` is the number of **bytes** (UTF-8 for text; raw for the body),
  not the number of characters. In Node: `Buffer.byteLength(s, 'utf8')`.
- The default `algorithm` is `sha512`. `hex` is lowercase hexadecimal.
- The whole canonical string is assembled as raw bytes, so a binary body is
  handled with no special casing.

## canonical_query

The query string is canonicalized by splitting it into its raw `key=value` pairs
on `&`, sorting those pairs in **byte order**, and re-joining them with `&`:

```
canonical_query = query.split("&").sortByBytes().join("&")     # "" if query is empty
```

- The pairs are kept **exactly as they appear on the wire** (percent-encoded).
  Values are never decoded, re-encoded, or type-converted for signing.
- "Byte order" means comparing the UTF-8 byte sequences of the pairs. Ruby's
  `Array#sort` on strings already does this. In JavaScript, the default
  `Array.prototype.sort` compares UTF-16 code units, which agrees with byte
  order for the Basic Multilingual Plane but **diverges for astral characters**
  (> U+FFFF); a conformant implementation MUST sort by encoded bytes, e.g. by
  comparing `Buffer`/`Uint8Array` representations, not raw JS string `<`/`>`.
- Sorting means the sender may emit pairs in any order; both sides re-sort before
  signing, so pair order in transit is irrelevant.

## Value stringification (senders building a query from a map)

When a helper builds the query string from a key/value map (the ergonomic
sender path), values become strings as follows before percent-encoding:

- **String** → itself.
- **Integer** → its decimal string. Big integers are exact (no float rounding).
- **Boolean** → `true` / `false`.
- **Symbol** (Ruby) → its string form.
- **Float** → its native string form (Ruby `Float#to_s`). Finite floats are
  allowed but their textual form is language-specific (Ruby `1.0` → `"1.0"`,
  JS `String(1.0)` → `"1"`). If you need byte-identical signatures from senders
  in different languages, use strings or integers for numeric values. **NaN and
  ±Infinity are rejected** (they have no stable representation).
- **Array** → a repeated key (`k=v1&k=v2`), elements stringified as above.
- **Hash / nested object** → not supported. v2 query params are flat `k=v`
  wire pairs; there is no nested or JSON encoding in the signing path. (A
  structured payload travels in the body, which is signed as raw bytes.)

None of this applies to the receiver: it never rebuilds values, it signs the
`query`/`body` bytes it received.

## Transport

Three headers carry the protocol metadata (names are configurable; defaults):

| Header          | Contents                                        |
|-----------------|-------------------------------------------------|
| `X-Signature`   | the hex HMAC signature                          |
| `X-M2M-Expiry`  | the expiry (integer Unix seconds), as a string  |
| `X-M2M-Nonce`   | the nonce                                        |

The expiry and nonce are **signed** (components 4 and 5), so they cannot be
tampered with; the headers are just how they travel.

## Expiry

The expiry is a Unix timestamp (seconds) chosen by the sender. The receiver
accepts the request only if it is strictly inside the window:

```
now < expiry < now + window          # window default: 120 seconds
```

Both bounds are strict (`expiry == now` and `expiry == now + window` are
rejected). This bounds how long a captured request could be replayed; clocks on
both ends are assumed roughly synchronized (NTP).

## Nonce and anti-replay

The expiry alone only *bounds* replay; a captured request can still be replayed
until it expires. The nonce closes that window:

- The sender generates a **unique, unpredictable** nonce per request (e.g.
  `SecureRandom.hex(16)`, ≥ 128 bits) and signs it.
- The receiver records nonces in a store and **rejects any nonce it has already
  seen**. The store operation MUST be a single **atomic** check-and-set
  (`add(nonce, ttl) -> was_new`); a separate "seen?" then "record" is a TOCTOU
  race that lets two concurrent replays through.
- The nonce's TTL in the store must cover at least the request's remaining
  acceptance window (`expiry - now`, plus a small clock-skew margin).
- **Fail closed**: if replay protection is enabled, a request with a missing or
  empty nonce is rejected.
- Nonce length should be bounded by the receiver to prevent store-memory abuse.

An implementation MAY offer an explicit opt-out (expiry-only, no nonce store),
but it must be a deliberate, visible choice — never a silent default.

## Reproducing a signature with OpenSSL

Build the canonical string and pipe it to `openssl`. For the first golden vector
below (`secret = golden-vector-secret`):

```sh
printf '%s' \
  '12:m2m-keygen/23:GET6:/users10:170000000016:nonce-simple-get7:a=1&b=20:' \
  | openssl dgst -sha256 -hmac 'golden-vector-secret'
# => 178ef6ed485b438422fa634c11e2a9497176d69abe98175ee9492503bed345ab
```

The canonical string reads: `12:` + `m2m-keygen/2`, `3:` + `GET`, `6:` + `/users`,
`10:` + `1700000000`, `16:` + `nonce-simple-get`, `7:` + `a=1&b=2`, `0:` + `` (empty body).

## Golden vectors

Secret: `golden-vector-secret`. Each row lists the inputs and the expected
lowercase-hex HMAC for both `sha256` and `sha512`. A conformant implementation
must reproduce every digest. (These are kept in sync with
`spec/support/golden_vectors.rb`.)

### 1. Simple GET with a sorted query

- verb `GET`, path `/users`, expiry `1700000000`, nonce `nonce-simple-get`, query `a=1&b=2`, body *(empty)*
- sha256: `178ef6ed485b438422fa634c11e2a9497176d69abe98175ee9492503bed345ab`
- sha512: `88fd787042faffd81584b534a9fb1f634907fc8ae742ff14b96da4b2f98dbddc25492776bbab30e37c59bb63a4ff84f1e22a359d015d463c1bbaa71f08319ae3`

### 2. POST with a JSON body

- verb `POST`, path `/users`, expiry `1700000100`, nonce `nonce-simple-post`, query *(empty)*, body `{"name":"Ada"}`
- sha256: `d1e464edbae8637f7db51c0f858a9a64db2c93208381c8055c2e4787b3fc5589`
- sha512: `c1f52dcfa6f880d1e601ff6db4889e64678e5057872e1a8e1831232e49ac2487a9c30981cbb67eff9e2dc3e7f54d4e05966bcd4d5bcb9b7f19a77204bd37ad6e`

### 3. Non-ASCII bytes in path, query and body

- verb `POST`, path `/résumé`, expiry `1700000200`, nonce `nonce-non-ascii`, query `name=%C3%A9l%C3%A8ve`, body `café ☃ 日本語`
- sha256: `66d0c10cca4b61021fcce45f27c07ffde3fb92e96f4fefbfb90283eaed84faa4`
- sha512: `75009832682f8e4ad03527000bc45a1885867b7965969f5b359c4e5af36fdc91b19ca58c1ab0dab2c6027531ec9ffcc8538287e6a06032fc077ccc865d188675`

### 4. Body with control characters (tab, newline, NUL)

- verb `POST`, path `/notes`, expiry `1700000300`, nonce `nonce-control-char`, query *(empty)*, body `control\tchars\n\x00end-of-line`
- sha256: `841172d2cea40129d864b5f1ef078329d33b4221c2227ed05058716104e75ad7`
- sha512: `49f58297da8599bc0d325d22cb1ed90ee7d5f67b13a9b13ca430820b8a09e08aff945129f6876bc0186002412eeae20b27dec1317c3f77f3eccb635899536b22`

### 5. Big-integer amount in query and body

- verb `POST`, path `/ledger`, expiry `1700000400`, nonce `nonce-bignum`, query `amount=123456789012345678901234567890`, body `{"amount":123456789012345678901234567890}`
- sha256: `b07e7563ce1f7c4819f3052ba3628a1a5d155b77600a5765c40ca610784e7808`
- sha512: `32078f4c96255ef99ca9e80ecb4ec800d4056ef136dbd42dc4c3bbfc33b153c3e2ef23a1a09b574d4ffd558ede3d30bcfc1c3cc041deaf5c76c70307e18a3c5d`

## Out of scope (threat model)

The scheme protects request **integrity** and **freshness** (replay). It does
**not** provide confidentiality (use TLS), does not bind the host/scheme (a
signed request is valid against any deployment sharing the secret — use
per-environment secrets), and assumes roughly synchronized clocks. Secret
rotation and host binding are possible extensions, not part of v2.
