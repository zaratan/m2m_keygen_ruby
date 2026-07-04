# typed: false

require 'rack'

describe M2mKeygen::RequestSigner do
  let(:secret) { 'secret' }
  let(:algorithm) { 'sha256' }
  let(:signer) { described_class.new(secret, algorithm: algorithm) }
  let(:nonce_store) { M2mKeygen::NonceStore::Memory.new }
  let(:validator) do
    M2mKeygen::RackValidator.new(
      secret,
      algorithm: algorithm,
      nonce_store: nonce_store,
    )
  end

  define_method(:rack_env_for) do |verb:, path:, query:, body:, headers:|
    {
      'REQUEST_METHOD' => verb,
      'PATH_INFO' => path,
      'QUERY_STRING' => query,
      'rack.input' => StringIO.new(body),
      'rack.url_scheme' => 'http',
      'HTTP_HOST' => 'localhost:3000',
    }.merge(
      headers.transform_keys { |name| "HTTP_#{name.tr('-', '_').upcase}" },
    )
  end

  describe '#sign_request' do
    it 'generates a non-empty nonce and a future expiry when none are given' do
      result = signer.sign_request(verb: 'GET', path: '/path')

      expect(result.headers['X-M2M-Nonce']).to be_a(String)
      expect(result.headers['X-M2M-Nonce']).not_to be_empty
      expect(result.headers['X-M2M-Expiry'].to_i).to be > Time.now.to_i
    end

    it 'uses the given expiry and nonce instead of generating them' do
      result =
        signer.sign_request(
          verb: 'GET',
          path: '/path',
          expiry: 1_700_000_000,
          nonce: 'fixed-nonce',
        )

      expect(result.headers['X-M2M-Expiry']).to eq('1700000000')
      expect(result.headers['X-M2M-Nonce']).to eq('fixed-nonce')
    end

    it 'builds a percent-encoded query string from params' do
      result =
        signer.sign_request(
          verb: 'GET',
          path: '/path',
          params: {
            'b' => 1,
            'a' => 'x y',
          },
        )

      expect(result.query).to eq('b=1&a=x+y')
    end

    it 'repeats the key for each element of an Array value' do
      result =
        signer.sign_request(
          verb: 'GET',
          path: '/path',
          params: {
            'tag' => %w[a b],
          },
        )

      expect(result.query).to eq('tag=a&tag=b')
    end

    it 'coerces Symbol values to strings' do
      with_symbol =
        signer.sign_request(
          verb: 'GET',
          path: '/path',
          params: {
            'status' => :active,
          },
          expiry: 1_700_000_000,
          nonce: 'n',
        )
      with_string =
        signer.sign_request(
          verb: 'GET',
          path: '/path',
          params: {
            'status' => 'active',
          },
          expiry: 1_700_000_000,
          nonce: 'n',
        )

      expect(with_symbol.query).to eq(with_string.query)
    end

    it 'respects custom header names' do
      custom_signer =
        described_class.new(
          secret,
          header_name: 'X-Sig',
          expiry_header: 'X-Exp',
          nonce_header: 'X-Nonce',
        )

      result = custom_signer.sign_request(verb: 'GET', path: '/path')

      expect(result.headers.keys).to contain_exactly(
        'X-Sig',
        'X-Exp',
        'X-Nonce',
      )
    end

    context 'when a param value is a finite Float' do
      it 'signs it using its Ruby string representation' do
        result =
          signer.sign_request(
            verb: 'GET',
            path: '/path',
            params: {
              'amount' => 1.5,
              'whole' => 1.0,
            },
          )

        expect(result.query).to eq('amount=1.5&whole=1.0')
      end
    end

    context 'when a param value is a non-finite Float (NaN/Infinity)' do
      it 'raises M2mKeygen::CanonicalizationError' do
        [Float::NAN, Float::INFINITY, -Float::INFINITY].each do |value|
          expect do
            signer.sign_request(
              verb: 'GET',
              path: '/path',
              params: {
                'amount' => value,
              },
            )
          end.to raise_error(M2mKeygen::CanonicalizationError)
        end
      end
    end
  end

  describe 'round-trip with RackValidator' do
    it 'validates a signed GET request with query params' do
      result =
        signer.sign_request(
          verb: 'GET',
          path: '/path',
          params: {
            'a' => 1,
            'b' => 'two',
          },
        )
      req =
        Rack::Request.new(
          rack_env_for(
            verb: 'GET',
            path: '/path',
            query: result.query,
            body: '',
            headers: result.headers,
          ),
        )

      expect(validator.validate(req)).to be(true)
    end

    it 'validates a signed POST request with a body' do
      body = '{"amount":42}'
      result = signer.sign_request(verb: 'POST', path: '/orders', body: body)
      req =
        Rack::Request.new(
          rack_env_for(
            verb: 'POST',
            path: '/orders',
            query: '',
            body: body,
            headers: result.headers,
          ),
        )

      expect(validator.validate(req)).to be(true)
    end

    it 'rejects a replayed signed request' do
      result = signer.sign_request(verb: 'GET', path: '/path')
      req =
        Rack::Request.new(
          rack_env_for(
            verb: 'GET',
            path: '/path',
            query: '',
            body: '',
            headers: result.headers,
          ),
        )

      expect(validator.validate(req)).to be(true)
      expect(validator.validate(req)).to be(false)
    end

    it 'rejects the request when a query param is tampered with after signing' do
      result =
        signer.sign_request(verb: 'GET', path: '/path', params: { 'a' => 1 })
      req =
        Rack::Request.new(
          rack_env_for(
            verb: 'GET',
            path: '/path',
            query: 'a=2',
            body: '',
            headers: result.headers,
          ),
        )

      expect(validator.validate(req)).to be(false)
    end
  end
end
