# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.1] - 2026-07-04

### Fixed

- `RackValidator` no longer raises when the Rack input stream is not rewindable
  or is absent. Rack 3 made `rack.input#rewind` optional, and `Rack::Lint`
  (rackup's development default) hides it; the body is now read once and only
  rewound when the stream supports it.

## [0.5.0] - 2026-07-03

**This release replaces the signature scheme with a new, incompatible one
(`m2m-keygen/2`). Senders and receivers must upgrade together. See
[docs/MIGRATING.md](docs/MIGRATING.md).**

### Added

- New `m2m-keygen/2` signature scheme: the HMAC now covers the request's wire
  bytes (method, path, byte-order-sorted query, raw body) length-prefixed, plus
  a signed expiry and nonce. This closes the v1 canonicalization collisions
  (unescaped delimiters, nil/empty ambiguity, type confusion, field boundaries).
- Anti-replay: a signed per-request nonce plus a pluggable `NonceStore`
  (`Memory` for single-process, `Disabled` for an explicit opt-out), with
  reference `Redis`/`Postgres` stores under `examples/nonce_store/`.
- `RequestSigner`: a client helper that builds the query and the
  signature/expiry/nonce headers for an outgoing request.
- `docs/SPEC.md`: the language-agnostic wire-format spec and golden vectors —
  the contract the TypeScript sibling must reproduce.
- CI now tests Ruby 3.3/3.4/4.0 and a Rack 2 / Rack 3 compatibility matrix.

### Changed

- **BREAKING** `Signature#sign` / `#validate` take
  `verb:`/`path:`/`expiry:`/`nonce:`/`query:`/`body:` (no longer a `params:`
  hash).
- **BREAKING** `RackValidator.new` now requires a `nonce_store:` (no default —
  the anti-replay choice must be explicit), and reads the expiry and nonce from
  `X-M2M-Expiry` / `X-M2M-Nonce` headers.
- Require Ruby `>= 3.3` (was `>= 2.7`); bind runtime deps
  (`rack (>= 2.2, < 4.0)`, `sorbet-runtime (>= 0.5)`, `zeitwerk (>= 2.6, < 3.0)`).
- Replace Prettier with Syntax Tree and Solargraph with ruby-lsp; upgrade dev
  dependencies (RuboCop 1.88, Sorbet 0.6, RSpec 3.13, Tapioca 0.19, …) and
  Bundler 4.

### Removed

- **BREAKING** `ParamsEncoder` (replaced by `Canonicalizer`) and the v1 hash-based
  signing input.
- Committed YARD HTML documentation and the Ruby 2.7 constant-time comparison
  fallback.

### Security

- Real replay protection: signed nonces enforced through the `NonceStore`
  (the receiver fails closed on a missing nonce unless replay protection is
  explicitly disabled).
- `Signature` no longer exposes the secret through a public reader and masks it
  in `#inspect`.
- Update dependencies to clear all known advisories (rexml, concurrent-ruby,
  yard, …).

### Fixed

- Restore the published gem metadata (homepage, source code, changelog and bug
  tracker URIs) that was previously overwritten.

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

[unreleased]: https://github.com/zaratan/m2m_keygen_ruby/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/zaratan/m2m_keygen_ruby/releases/tag/v0.5.1
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
