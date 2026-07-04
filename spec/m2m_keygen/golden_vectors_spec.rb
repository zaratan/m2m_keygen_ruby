# typed: false

describe 'm2m-keygen/2 golden vectors' do
  algorithms = %i[sha256 sha512].freeze

  GoldenVectors::VECTORS.each do |vector|
    context "with #{vector[:name]}" do
      algorithms.each do |algorithm|
        it "reproduces the frozen #{algorithm} signature" do
          signature =
            M2mKeygen::Signature.new(
              GoldenVectors::SECRET,
              algorithm: algorithm.to_s,
            )

          computed =
            signature.sign(
              verb: vector[:verb],
              path: vector[:path],
              expiry: vector[:expiry],
              nonce: vector[:nonce],
              query: vector[:query],
              body: vector[:body],
            )

          expect(computed).to eq(vector.fetch(algorithm))
        end
      end
    end
  end
end
