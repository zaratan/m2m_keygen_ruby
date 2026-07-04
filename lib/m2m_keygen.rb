# typed: strict

require 'sorbet-runtime'
require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.setup

# Main module
module M2mKeygen
  # Standard error for the gem
  class Error < StandardError
  end

  # Raised when an input cannot be turned into the canonical signing string
  # (e.g. an unsupported value type). Surfaces loudly on the signer side; the
  # verifier turns it into a `false` result.
  class CanonicalizationError < Error
  end
end
