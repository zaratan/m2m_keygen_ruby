# typed: false

require 'rack/utils'
require 'json'

describe M2mKeygen::Canonicalizer do
  describe '.canonical' do
    subject(:canonical) do
      described_class.canonical(
        verb: 'GET',
        path: '/users',
        expiry: 1_700_000_000,
        nonce: 'abc',
        query: 'a=1&b=2',
        body: '',
      )
    end

    it 'concatenates each component as "<utf8_bytesize>:<bytes>"' do
      expect(canonical).to eq(
        '12:m2m-keygen/2' \
          '3:GET' \
          '6:/users' \
          '10:1700000000' \
          '3:abc' \
          '7:a=1&b=2' \
          '0:',
      )
    end

    it 'upcases the verb' do
      lowercase =
        described_class.canonical(
          verb: 'get',
          path: '/users',
          expiry: 1_700_000_000,
          nonce: 'abc',
          query: 'a=1&b=2',
          body: '',
        )

      expect(lowercase).to eq(canonical)
    end

    it 'returns a binary-encoded string' do
      expect(canonical.encoding).to eq(Encoding::BINARY)
    end

    it 'length-prefixes using UTF-8 bytesize, not character count' do
      canonical_with_multibyte_path =
        described_class.canonical(
          verb: 'GET',
          path: '/café',
          expiry: 1_700_000_000,
          nonce: 'abc',
          query: '',
          body: '',
        )

      expect(canonical_with_multibyte_path).to include('6:/café'.b)
      expect('/café'.bytesize).to eq(6)
      expect('/café'.length).to eq(5)
    end
  end

  describe '.canonical_query' do
    it 'returns an empty string for an empty query' do
      expect(described_class.canonical_query('')).to eq('')
    end

    it 'sorts pairs so that argument order does not matter' do
      expect(described_class.canonical_query('b=2&a=1')).to eq(
        described_class.canonical_query('a=1&b=2'),
      )
    end

    it 'sorts by raw byte order, not case-insensitive alphabetical order' do
      expect(described_class.canonical_query('a=2&B=1')).to eq('B=1&a=2')
    end
  end

  describe 'injectivity: former v1 collisions now canonicalize differently' do
    define_method(:canonical_for) do |query: '', body: ''|
      described_class.canonical(
        verb: 'POST',
        path: '/x',
        expiry: 1_700_000_000,
        nonce: 'n',
        query: query,
        body: body,
      )
    end

    it 'no longer collides on an unescaped delimiter inside a value (C1)' do
      # v1 built "a=1&b=2" whether the source was {a: 1, b: 2} (two pairs) or
      # {a: "1&b=2"} (one value containing a literal "&"/"="), because it
      # simply string-joined values without escaping. In v2 the client is
      # responsible for percent-encoding its query values (Rack::Utils does
      # this for RequestSigner); a literal "&"/"=" inside a value is escaped
      # and therefore cannot be split into extra pairs by canonical_query.
      two_pairs = Rack::Utils.build_query({ 'a' => 1, 'b' => 2 })
      one_escaped_pair = Rack::Utils.build_query({ 'a' => '1&b=2' })

      expect(two_pairs).to eq('a=1&b=2')
      expect(one_escaped_pair).to eq('a=1%26b%3D2')
      expect(canonical_for(query: two_pairs)).not_to eq(
        canonical_for(query: one_escaped_pair),
      )
    end

    it 'distinguishes an empty value from an absent key (C2)' do
      # v1's ParamsEncoder dropped both nil values and empty-string values,
      # so {a: "", b: 2} and {b: 2} both encoded to "b=2". The v2 query
      # string is signed verbatim: "a" present-but-empty stays in the text.
      present_but_empty = 'a=&b=2'
      absent = 'b=2'

      expect(canonical_for(query: present_but_empty)).not_to eq(
        canonical_for(query: absent),
      )
    end

    it 'does not conflate an Integer body value with its String twin (C3/C4 type confusion)' do
      # v1 parsed the JSON body into typed params, then re-serialized those
      # params for signing — so a body of {"amount":1} and a body of
      # {"amount":"1"} could end up re-serialized to the same signed text.
      # v2 signs the body exactly as received, with no parse/re-serialize
      # round trip, so these two distinct byte sequences stay distinct.
      integer_amount_body = JSON.generate({ 'amount' => 1 })
      string_amount_body = JSON.generate({ 'amount' => '1' })

      expect(integer_amount_body).to eq('{"amount":1}')
      expect(string_amount_body).to eq('{"amount":"1"}')
      expect(canonical_for(body: integer_amount_body)).not_to eq(
        canonical_for(body: string_amount_body),
      )
    end

    it 'cannot conflate a Hash value with an equivalent JSON String value (C3/C4 hash-vs-string)' do
      # v1 JSON-encoded nested Hash param values for signing, so a param
      # {b: {c: "1"}} (a Hash) and a param {b: '{"c":"1"}'} (a String that
      # happens to already look like that JSON) could both render to the
      # same "b={\"c\":\"1\"}" signed text. In v2 there is no hash-to-JSON
      # step: Rack::Utils.build_query (used by RequestSigner) renders a Hash
      # value via Ruby's own #to_s/inspect, which uses "=>" and is therefore
      # never byte-identical to the JSON rendering of an equivalent String.
      hash_value_query = Rack::Utils.build_query({ 'b' => { 'c' => '1' } })
      json_string_value_query =
        Rack::Utils.build_query({ 'b' => JSON.generate({ 'c' => '1' }) })

      expect(hash_value_query).not_to eq(json_string_value_query)
      expect(canonical_for(query: hash_value_query)).not_to eq(
        canonical_for(query: json_string_value_query),
      )
    end

    it 'does not let a character migrate across the verb/path boundary (C6)' do
      # Naive concatenation of VERB + path would make "GET" + "A/b" produce
      # the exact same string as "GETA" + "/b" ("GETA/b" either way).
      # Length-prefixing each component makes that boundary unforgeable.
      shifted_into_path =
        described_class.canonical(
          verb: 'GET',
          path: 'A/b',
          expiry: 1,
          nonce: 'n',
          query: '',
          body: '',
        )
      shifted_into_verb =
        described_class.canonical(
          verb: 'GETA',
          path: '/b',
          expiry: 1,
          nonce: 'n',
          query: '',
          body: '',
        )

      expect(shifted_into_path).not_to eq(shifted_into_verb)
    end

    it 'does not let a character migrate across the query/body boundary (C6)' do
      # Naive concatenation of query + body would make "a=1" + "&b=2" equal
      # "a=1&b=2" + "" ("a=1&b=2" either way). Length-prefixing fixes this.
      shifted_into_body = canonical_for(query: 'a=1', body: '&b=2')
      shifted_into_query = canonical_for(query: 'a=1&b=2', body: '')

      expect(shifted_into_body).not_to eq(shifted_into_query)
    end
  end
end
