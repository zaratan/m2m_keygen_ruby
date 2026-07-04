# typed: false

# Frozen input -> hex-digest vectors: the cross-language contract for the
# m2m-keygen/2 wire format. See docs/SPEC.md for the format and how to
# reproduce a vector with the OpenSSL CLI.
module GoldenVectors
  SECRET = 'golden-vector-secret'

  VECTORS = [
    {
      name: 'a simple GET request with a sorted query string',
      verb: 'GET',
      path: '/users',
      expiry: 1_700_000_000,
      nonce: 'nonce-simple-get',
      query: 'a=1&b=2',
      body: '',
      sha256:
        '178ef6ed485b438422fa634c11e2a9497176d69abe98175ee9492503bed345ab',
      sha512:
        '88fd787042faffd81584b534a9fb1f634907fc8ae742ff14b96da4b2f98dbddc25492776bbab30e37c59bb63a4ff84f1e22a359d015d463c1bbaa71f08319ae3',
    },
    {
      name: 'a POST request with a JSON body',
      verb: 'POST',
      path: '/users',
      expiry: 1_700_000_100,
      nonce: 'nonce-simple-post',
      query: '',
      body: '{"name":"Ada"}',
      sha256:
        'd1e464edbae8637f7db51c0f858a9a64db2c93208381c8055c2e4787b3fc5589',
      sha512:
        'c1f52dcfa6f880d1e601ff6db4889e64678e5057872e1a8e1831232e49ac2487a9c30981cbb67eff9e2dc3e7f54d4e05966bcd4d5bcb9b7f19a77204bd37ad6e',
    },
    {
      name: 'non-ASCII bytes in the path, query and body',
      verb: 'POST',
      path: '/résumé',
      expiry: 1_700_000_200,
      nonce: 'nonce-non-ascii',
      query: 'name=%C3%A9l%C3%A8ve',
      body: 'café ☃ 日本語',
      sha256:
        '66d0c10cca4b61021fcce45f27c07ffde3fb92e96f4fefbfb90283eaed84faa4',
      sha512:
        '75009832682f8e4ad03527000bc45a1885867b7965969f5b359c4e5af36fdc91b19ca58c1ab0dab2c6027531ec9ffcc8538287e6a06032fc077ccc865d188675',
    },
    {
      name: 'a body containing control characters (tab, newline, NUL)',
      verb: 'POST',
      path: '/notes',
      expiry: 1_700_000_300,
      nonce: 'nonce-control-char',
      query: '',
      body: "control\tchars\n\x00end-of-line",
      sha256:
        '841172d2cea40129d864b5f1ef078329d33b4221c2227ed05058716104e75ad7',
      sha512:
        '49f58297da8599bc0d325d22cb1ed90ee7d5f67b13a9b13ca430820b8a09e08aff945129f6876bc0186002412eeae20b27dec1317c3f77f3eccb635899536b22',
    },
    {
      name: 'a Bignum-sized amount in the query and the body',
      verb: 'POST',
      path: '/ledger',
      expiry: 1_700_000_400,
      nonce: 'nonce-bignum',
      query: 'amount=123456789012345678901234567890',
      body: '{"amount":123456789012345678901234567890}',
      sha256:
        'b07e7563ce1f7c4819f3052ba3628a1a5d155b77600a5765c40ca610784e7808',
      sha512:
        '32078f4c96255ef99ca9e80ecb4ec800d4056ef136dbd42dc4c3bbfc33b153c3e2ef23a1a09b574d4ffd558ede3d30bcfc1c3cc041deaf5c76c70307e18a3c5d',
    },
  ].freeze
end
