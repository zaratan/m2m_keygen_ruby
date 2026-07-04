# typed: strict

module M2mKeygen
  class RequestSigner
    class SignedRequest < T::Struct
      const :headers, T::Hash[String, String]
      const :query, String
    end
  end
end
