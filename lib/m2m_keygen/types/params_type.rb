# typed: strict
module M2mKeygen
  module Types
    extend T::Sig

    ParamsScalarType =
      T.type_alias { T.any(String, Symbol, Integer, Float, T::Boolean) }

    ParamsValueType =
      T.type_alias { T.any(ParamsScalarType, T::Array[ParamsScalarType]) }

    ParamsType =
      T.type_alias { T::Hash[T.any(String, Symbol), ParamsValueType] }
  end
end
