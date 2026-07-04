# typed: false

require 'rack'

describe M2mKeygen::RackValidator do
  let(:secret) { 'secret' }
  let(:algorithm) { 'sha512' }
  let(:header_name) { 'X-Signature' }
  let(:expiry_header) { 'X-M2M-Expiry' }
  let(:nonce_header) { 'X-M2M-Nonce' }
  let(:window) { 120 }
  let(:nonce_store) { M2mKeygen::NonceStore::Memory.new }
  let(:validator) do
    M2mKeygen::RackValidator.new(
      secret,
      algorithm: algorithm,
      header_name: header_name,
      nonce_store: nonce_store,
      window: window,
      expiry_header: expiry_header,
      nonce_header: nonce_header,
    )
  end

  let(:verb) { 'GET' }
  let(:path) { '/path' }
  let(:query_string) { 'a=2&b=1' }
  let(:body) { '' }
  let(:expiry) { Time.now.to_i + 60 }
  let(:nonce) { 'nonce-value' }
  let(:signature) do
    validator.signature.sign(
      verb: verb,
      path: path,
      expiry: expiry,
      nonce: nonce,
      query: query_string,
      body: body,
    )
  end
  let(:signature_env_key) { "HTTP_#{header_name.tr('-', '_').upcase}" }
  let(:expiry_env_key) { "HTTP_#{expiry_header.tr('-', '_').upcase}" }
  let(:nonce_env_key) { "HTTP_#{nonce_header.tr('-', '_').upcase}" }
  let(:auth_env) do
    {
      signature_env_key => signature,
      expiry_env_key => expiry.to_s,
      nonce_env_key => nonce,
    }
  end
  let(:req_env) do
    auth_env.merge(
      'rack.url_scheme' => 'http',
      'QUERY_STRING' => query_string,
      'REQUEST_METHOD' => verb,
      'HTTP_VERSION' => 'HTTP/1.1',
      'HTTP_HOST' => 'localhost:3000',
      'PATH_INFO' => path,
      'rack.input' => StringIO.new(body),
    )
  end
  let(:req) { Rack::Request.new(req_env) }

  describe 'initialization' do
    it 'requires a nonce_store with no default' do
      expect { M2mKeygen::RackValidator.new(secret) }.to raise_error(
        ArgumentError,
      )
    end

    it 'initializes the signature with the secret and the algorithm' do
      expect(M2mKeygen::Signature).to receive(:new).with(
        secret,
        algorithm: algorithm,
      ).and_call_original
      expect(validator.signature).to be_a(M2mKeygen::Signature)
    end

    it 'formats the header name into a Rack env key' do
      expect(validator.header_name).to eq('HTTP_X_SIGNATURE')
    end
  end

  describe '#validate' do
    subject(:validate) { validator.validate(req) }

    it 'works in the normal case' do
      expect(validate).to be(true)
    end

    context 'when the nonce header is longer than the allowed maximum' do
      let(:nonce) { 'n' * (described_class::MAX_NONCE_BYTES + 1) }

      it 'is rejected before signing' do
        expect(validate).to be(false)
      end
    end

    context 'with a percent-encoded non-ASCII path (wire form)' do
      let(:path) { '/r%C3%A9sum%C3%A9' }

      it { is_expected.to be(true) }
    end

    context 'when the signature is invalid' do
      let(:signature) { 'invalid' }

      it { is_expected.to be(false) }
    end

    context 'when the verb does not match what was signed' do
      let(:signature) do
        validator.signature.sign(
          verb: 'POST',
          path: path,
          expiry: expiry,
          nonce: nonce,
          query: query_string,
          body: body,
        )
      end

      it { is_expected.to be(false) }
    end

    context 'when the path does not match what was signed' do
      let(:path) { '/other' }
      let(:signature) do
        validator.signature.sign(
          verb: verb,
          path: '/path',
          expiry: expiry,
          nonce: nonce,
          query: query_string,
          body: body,
        )
      end

      it { is_expected.to be(false) }
    end

    context 'when the expiry is in the past' do
      let(:expiry) { Time.now.to_i - 60 }

      it { is_expected.to be(false) }
    end

    context 'when the expiry is far beyond the window' do
      let(:expiry) { Time.now.to_i + window + 60 }

      it { is_expected.to be(false) }
    end

    context 'at the exact window boundaries' do
      let(:frozen_now) { Time.at(1_700_000_000) }

      before { allow(Time).to receive(:now).and_return(frozen_now) }

      context 'when expiry equals now (not strictly in the future)' do
        let(:expiry) { frozen_now.to_i }

        it { is_expected.to be(false) }
      end

      context 'when expiry equals now + window (not strictly inside it)' do
        let(:expiry) { frozen_now.to_i + window }

        it { is_expected.to be(false) }
      end

      context 'when expiry is one second past now' do
        let(:expiry) { frozen_now.to_i + 1 }

        it { is_expected.to be(true) }
      end

      context 'when expiry is one second inside the window' do
        let(:expiry) { frozen_now.to_i + window - 1 }

        it { is_expected.to be(true) }
      end
    end

    context 'when the query string differs from what was signed' do
      let(:signature) do
        validator.signature.sign(
          verb: verb,
          path: path,
          expiry: expiry,
          nonce: nonce,
          query: 'a=2&b=1&c=3',
          body: body,
        )
      end

      it { is_expected.to be(false) }
    end

    context 'when the nonce header is absent' do
      let(:auth_env) { super().reject { |key, _| key == nonce_env_key } }

      it 'fails closed instead of validating without a nonce' do
        expect(validate).to be(false)
      end
    end

    context 'when the nonce header is present but empty' do
      let(:nonce) { '' }

      it 'fails closed' do
        expect(validate).to be(false)
      end
    end

    context 'when the nonce is replayed' do
      it 'accepts the first request and rejects the identical second one' do
        expect(validator.validate(req)).to be(true)
        expect(validator.validate(req)).to be(false)
      end
    end

    context 'with a Disabled nonce store' do
      let(:nonce_store) { M2mKeygen::NonceStore::Disabled.new }
      let(:nonce) { '' }

      it 'does not fail closed on a missing nonce' do
        expect(validate).to be(true)
      end

      it 'allows the same request to be replayed (expiry-only enforcement)' do
        expect(validator.validate(req)).to be(true)
        expect(validator.validate(req)).to be(true)
      end
    end

    context 'with a custom signature header name' do
      let(:header_name) { 'X-My-Signature' }

      it 'reads the signature from the configured header' do
        expect(validate).to be(true)
      end
    end

    context 'with custom expiry and nonce header names' do
      let(:expiry_header) { 'X-Custom-Expiry' }
      let(:nonce_header) { 'X-Custom-Nonce' }

      it 'reads expiry and nonce from the configured headers' do
        expect(validate).to be(true)
      end
    end

    it 'rewinds the request body so it can be read downstream' do
      validator.validate(req)

      expect(req.env['rack.input'].read).to eq(body)
    end

    context 'with a POST body' do
      let(:verb) { 'POST' }
      let(:query_string) { '' }
      let(:body) { '{"name":"Ada"}' }

      it 'validates the signed body and still leaves it rewound' do
        expect(validate).to be(true)
        expect(req.env['rack.input'].read).to eq(body)
      end
    end
  end
end
