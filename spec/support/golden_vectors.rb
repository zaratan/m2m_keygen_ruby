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
      name: 'a percent-encoded path (wire form) with non-ASCII query and body',
      verb: 'POST',
      path: '/r%C3%A9sum%C3%A9',
      expiry: 1_700_000_200,
      nonce: 'nonce-non-ascii',
      query: 'name=%C3%A9l%C3%A8ve',
      body: 'café ☃ 日本語',
      sha256:
        '4d521773b4b15bff07e73c4a4a8db483314b62725b42b653e2d887efdca78404',
      sha512:
        'ec42e774af9730d59456fcf2909d7606a10d61d4187badf2b0f7b4b62047495daa4d9f5d286bdb1e4b9a61b8b23e5801e13b563177c3e7f3d6f553f6dad6f7f1',
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
    {
      name: 'an out-of-order multi-pair query (proves the pair sort)',
      verb: 'GET',
      path: '/list',
      expiry: 1_700_000_500,
      nonce: 'nonce-sort',
      query: 'b=2&a=10&a=1',
      body: '',
      sha256:
        'f3da6c2db729b59fdbaa301eb1bebea55253afdcd6039e055849a6404ffdd845',
      sha512:
        'db925510d0621073b4a37441f3f0df8697b08d204feae25f663a284840cbaceced9cd28acad09121f7d64749d4c6ab690c279dcc6b14b6a5ad81c0dce86d3cc2',
    },
    {
      name:
        'an astral character in the query (proves byte-order, not UTF-16, sorting)',
      verb: 'GET',
      path: '/emoji',
      expiry: 1_700_000_600,
      nonce: 'nonce-astral',
      query: "\u{1F600}=astral&\u{FFFD}=bmp",
      body: '',
      sha256:
        '32f0e93a4f926293d232a0a81cebbe5206a9f7619413dd126bc7b9dd027bbb69',
      sha512:
        '4109fcd615c1a6231d4d8dac08416d28e0bf324bc7b65f3b8193651e7eed8c6a072c08df2e6c3c16daf8a921e6b2a8102e04e726521ac6d98e9c6128a6e44a69',
    },
  ].freeze
end
