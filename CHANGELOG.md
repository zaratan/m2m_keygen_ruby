# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-07-03

### Added

- Test the gem against Ruby 3.3, 3.4 and 4.0 in CI.
- CI compatibility matrix running the suite against both Rack 2 and Rack 3.

### Changed

- Require Ruby `>= 3.3` (was `>= 2.7`).
- Bind runtime dependencies: `rack (>= 2.2, < 4.0)`, `sorbet-runtime (>= 0.5)`,
  `zeitwerk (>= 2.6, < 3.0)`.
- `RackValidator#validate` now reads the signature from the configured
  `header_name` instead of a hardcoded `X-Signature` header.
- `Signature.new` raises `M2mKeygen::Error` on an unsupported algorithm,
  consistently across OpenSSL versions.
- Replace Prettier with Syntax Tree for formatting (removes the Node.js
  toolchain) and Solargraph with ruby-lsp.
- Upgrade development dependencies (RuboCop 1.88, Sorbet 0.6, RSpec 3.13,
  Tapioca 0.19, …) and Bundler 4; regenerate Sorbet RBIs.

### Fixed

- `RackValidator#validate` returns `false` instead of raising when the `expiry`
  parameter is missing.
- `RackValidator` no longer returns a 500 on a JSON body that is valid but not
  an object.
- `RackValidator` rewinds the request body so downstream middleware can read it.
- Restore the published gem metadata (homepage, source code, changelog and bug
  tracker URIs) that was previously overwritten.

### Removed

- Committed YARD HTML documentation and the Ruby 2.7 constant-time comparison
  fallback.

### Security

- Update dependencies to clear all known advisories (rexml, concurrent-ruby,
  yard, …).
- Stop exposing the HMAC secret through a public reader and mask it in
  `Signature#inspect`.

## [0.4.9] - 2026-07-01

### Added

- Support ASDF dev

## [0.4.8] - 2026-07-01

### Fixed

- Support Boolean fields

## [0.4.7] - 2023-10-04

### Fixed

- Various updates

## [0.4.6] - 2022-11-14

### Fixed

- Expiry can be part of JSON body

## [0.4.5] - 2022-11-14

### Fixed

- Expiry can be part of JSON body

## [0.4.4] - 2022-11-14

### Changed

- Body is parsed as JSON and added to the query string

## [0.4.3] - 2022-10-12

### Changed

- Updated all gems + prettier

## [0.4.2] - 2022-09-05

### Changed

- Request default value for params in RackValidator

## [0.4.1] - 2022-09-05

### Changed

- Loosening RackValidator initialize type.

## [0.4.0] - 2022-08-30

### Added

- Direct validation for `Rack::Request` like objects.

## [0.3.0] - 2022-08-30

### Added

- Signature class for basic functionality for the gem.
- ParamsEncoder class for formating params

### Changed

- Comprehensive README
- Added various minimal require

## [0.2.1] - 2022-08-29

### Added

- Good link to documentation

## [0.2.0] - 2022-08-29

### Added

- Basic skeleton for gem

[unreleased]: https://github.com/zaratan/m2m_keygen_ruby/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/zaratan/m2m_keygen_ruby/releases/tag/v0.5.0
[0.4.9]: https://github.com/zaratan/m2m_keygen_ruby/releases/tag/v0.4.9
[0.4.8]: https://github.com/zaratan/m2m_keygen_ruby/releases/tag/v0.4.8
[0.4.7]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.4.7
[0.4.6]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.4.6
[0.4.5]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.4.5
[0.4.4]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.4.4
[0.4.3]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.4.3
[0.4.2]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.4.2
[0.4.1]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.4.1
[0.4.0]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.4.0
[0.3.0]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.3.0
[0.2.1]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.2.1
[0.2.0]: https://github.com/Billcorporate/m2m_keygen_ruby/releases/tag/v0.2.0
