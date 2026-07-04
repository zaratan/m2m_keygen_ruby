# typed: false

describe M2mKeygen::Signature do
  let(:secret) { 'secret' }
  let(:algorithm) { 'sha256' }
  let(:signature) { M2mKeygen::Signature.new(secret, algorithm: algorithm) }

  describe 'initialization' do
    it 'does not expose the secret through a public reader' do
      expect(signature).not_to respond_to(:secret)
    end

    it 'masks the secret in inspect' do
      expect(signature.inspect).not_to include(secret)
      expect(signature.inspect).to include(algorithm)
    end

    it 'sets algorithm' do
      expect(signature.algorithm).to eq(algorithm)
    end

    context 'without algorithm' do
      let(:signature) { M2mKeygen::Signature.new(secret) }

      it 'sets algorithm to sha512' do
        expect(signature.algorithm).to eq('sha512')
      end
    end

    context 'with invalid algorithm' do
      let(:algorithm) { 'invalid' }

      it 'raises a gem error regardless of the OpenSSL version' do
        expect { signature }.to raise_error(
          M2mKeygen::Error,
          /Unsupported HMAC algorithm/,
        )
      end
    end
  end

  describe 'sign' do
    let(:verb) { 'get' }
    let(:path) { '/path' }
    let(:expiry) { 1_700_000_000 }
    let(:nonce) { 'nonce-value' }
    let(:query) { 'a=2&b=1' }
    let(:body) { '' }

    subject(:sign) do
      signature.sign(
        verb: verb,
        path: path,
        expiry: expiry,
        nonce: nonce,
        query: query,
        body: body,
      )
    end

    it 'returns the expected hex digest' do
      # Signature reproduced using the OpenSSL CLI:
      # printf '%s' \
      #   '12:m2m-keygen/23:GET5:/path10:170000000011:nonce-value7:a=2&b=10:' \
      #   | openssl dgst -sha256 -hmac 'secret'
      expect(sign).to eq(
        'da78610cbea329aa0272c3a03e760e386a45c9a226d547a7849028e4e0a0b6c5',
      )
    end

    it 'delegates canonicalization to Canonicalizer' do
      expect(M2mKeygen::Canonicalizer).to receive(:canonical).with(
        verb: verb,
        path: path,
        expiry: expiry,
        nonce: nonce,
        query: query,
        body: body,
      ).and_call_original
      sign
    end

    it 'upcases the verb before signing' do
      lowercase = sign
      uppercase =
        signature.sign(
          verb: verb.upcase,
          path: path,
          expiry: expiry,
          nonce: nonce,
          query: query,
          body: body,
        )

      expect(lowercase).to eq(uppercase)
    end

    context 'when the query pairs arrive in a different order' do
      let(:query) { 'b=1&a=2' }

      it 'produces the same signature, since canonical_query re-sorts' do
        expect(sign).to eq(
          'da78610cbea329aa0272c3a03e760e386a45c9a226d547a7849028e4e0a0b6c5',
        )
      end
    end
  end

  describe 'validate' do
    let(:verb) { 'get' }
    let(:path) { '/path' }
    let(:expiry) { 1_700_000_000 }
    let(:nonce) { 'nonce-value' }
    let(:query) { 'a=2&b=1' }
    let(:body) { '' }

    subject(:validate) do
      signature.validate(
        signature: received_signature,
        verb: verb,
        path: path,
        expiry: expiry,
        nonce: nonce,
        query: query,
        body: body,
      )
    end

    context 'with a valid signature' do
      let(:received_signature) do
        'da78610cbea329aa0272c3a03e760e386a45c9a226d547a7849028e4e0a0b6c5'
      end

      it { is_expected.to be_truthy }
    end

    context 'with an invalid signature' do
      let(:received_signature) do
        'da78610cbea329aa0272c3a03e760e386a45c9a226d547a7849028e4e0a0b6c8'
      end

      it { is_expected.to be_falsey }
    end

    context 'with an invalid length signature' do
      let(:received_signature) { 'da78610cbea329aa0272c3a03e760e386' }

      it { is_expected.to be_falsey }
    end

    context 'when any signed field differs' do
      let(:received_signature) do
        'da78610cbea329aa0272c3a03e760e386a45c9a226d547a7849028e4e0a0b6c5'
      end
      let(:nonce) { 'a-different-nonce' }

      it { is_expected.to be_falsey }
    end
  end
end
