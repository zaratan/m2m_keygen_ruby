# typed: strict
# frozen_string_literal: true

module M2mKeygen
  class Canonicalizer
    extend T::Sig

    SCHEME = 'm2m-keygen/2'

    class << self
      extend T::Sig

      sig do
        params(
          verb: String,
          path: String,
          expiry: Integer,
          nonce: String,
          query: String,
          body: String,
        ).returns(String)
      end
      def canonical(verb:, path:, expiry:, nonce:, query: '', body: '')
        join_length_prefixed(
          [
            SCHEME,
            verb.upcase,
            path,
            expiry.to_s,
            nonce,
            canonical_query(query),
            body,
          ],
        )
      end

      sig { params(query: String).returns(String) }
      def canonical_query(query)
        return '' if query.empty?

        query.split('&').sort_by(&:b).join('&')
      end

      private

      sig { params(components: T::Array[String]).returns(String) }
      def join_length_prefixed(components)
        buffer = String.new(encoding: Encoding::BINARY)
        components.each do |component|
          bytes = component.b
          buffer << bytes.bytesize.to_s << ':' << bytes
        end
        buffer
      end
    end
  end
end
