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
    let(:verb) { :get }
    let(:path) { '/path' }
    let(:params) { { 'b' => '1', 'a' => '2' } }

    it 'returns signature' do
      # Signature generated using OpenSSL cli
      # echo "GET/patha=2&b=1" | perl -0 -pe 's/\n\Z//' | openssl sha256 -hmac "secret"
      expect(signature.sign(params: params, verb: verb, path: path)).to eq(
        '7d86fa8a7f871589697b0f41542d065b1ddbbe155e83349fffd937edcfa85af7',
      )
    end

    it 'uses ParamsEncoder to encode params' do
      expect(M2mKeygen::ParamsEncoder).to receive(:new).with(
        params,
      ).and_call_original
      signature.sign(params: params, verb: verb, path: path)
    end

    it 'builds the string using the verb and the path' do
      # Sinature initialization calls OpenSSL::HMAC.hexdigest
      signature
      expect(OpenSSL::HMAC).to receive(:hexdigest).with(
        anything,
        anything,
        /#{verb.to_s.upcase}#{path}/,
      ).and_call_original
      signature.sign(params: params, verb: verb, path: path)
    end
  end

  describe 'validate' do
    let(:verb) { :get }
    let(:path) { '/path' }
    let(:params) { { 'b' => '1', 'a' => '2' } }

    subject(:validate) do
      signature.validate(
        params: params,
        verb: verb,
        path: path,
        signature: received_signature,
      )
    end

    context 'with a valid signature' do
      let(:received_signature) do
        '7d86fa8a7f871589697b0f41542d065b1ddbbe155e83349fffd937edcfa85af7'
      end
      it { is_expected.to be_truthy }
    end

    context 'with an invalid signature' do
      let(:received_signature) do
        '7d86fa8a7f871589697b0f41542d065b1ddbbe155e83349fffd937edcfa85af8'
      end
      it { is_expected.to be_falsey }
    end

    context 'with an invalid length signature' do
      let(:received_signature) do
        '7d86fa8a7f871589697b0f41542d065b1ddb349fffd937edcfa85af8'
      end
      it { is_expected.to be_falsey }
    end
  end
end
