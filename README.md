# M2mKeygen

This gem exists for simplifying Machine to Machine signature generation and verification in a secure way.

> If you are coming from a `0.4.x` version: the signature scheme changed in `0.5.0` and is not compatible anymore. See [docs/MIGRATING.md](docs/MIGRATING.md).

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add m2m_keygen

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install m2m_keygen

## Usage

The 2 servers share the same secret key. The sender will sign the request it is about to send and put the signature (with an expiry and a nonce) in headers. The receiver will generate the same signature from the request it received and compare them.

### Signing a request

You should use the `RequestSigner` on the sender side. It will build the query to send and the headers to add, and generate a nonce and an expiry for you.

- `verb` is the http verb
- `path` is the path for the request
- `params` is a params hash as used in Rack. The order of keys isn't important as the gem will reformat them.
- `body` is optional, the raw body you will send

```ruby
Signer = M2mKeygen::RequestSigner.new("my_secret_key") # eventually algorithm: "sha256", defaults to sha512

signed =
  Signer.sign_request(
    verb: "get",
    path: "/orders",
    params: {
      "since" => "2026-01-01",
      "limit" => 50
    }
  )

signed.query # => the query string to send
signed.headers # => the X-Signature, X-M2M-Expiry and X-M2M-Nonce headers to add
```

After signing, send `signed.query` and `signed.headers` alongside your request.

### Validating a request

You should initialize the `RackValidator` once (in an initializer for example) with your secret key, eventually an encryption algorithm, a header name for the signature, and a nonce store (see below).

It will validate :

- Signature matching
- That the `expiry` (in the `X-M2M-Expiry` header) is present and between now and in 2 minutes.
- That the `nonce` (in the `X-M2M-Nonce` header) has never been seen before, so the request can't be replayed.

```ruby
RackSignatureValidator =
  M2mKeygen::RackValidator.new(
    "my_secret_key",
    nonce_store: M2mKeygen::NonceStore::Memory.new,
    algorithm: "sha512", # Default value
    header_name: "X-Signature", # Default value
    window: 120 # Default value, in seconds
  )
```

You can then validate a Rack::Request or a Rails Request directly:

```ruby
RackSignatureValidator.validate(request) # => true or false
```

### Choosing a nonce store

The nonce is what really stops replay: a captured request can't be replayed because its nonce is remembered until it expires. You have to choose a store, there is no default value on purpose, so you don't end up without replay protection without knowing it.

- `M2mKeygen::NonceStore::Memory` for a single process app or in development. Careful : with several workers or several hosts, each process has its own memory, so the replay protection is only partial. Use a shared store in production.
- A shared store (Redis, Postgres, ...) for production. Ready to copy implementations are in [`examples/nonce_store/`](examples/nonce_store/).
- `M2mKeygen::NonceStore::Disabled` if you explicitly don't want the replay protection (expiry only).

### Signing without headers

If you don't go through HTTP headers, `Signature` is the low level tool both helpers are built on.

```ruby
Signature = M2mKeygen::Signature.new("my_secret_key")

hex =
  Signature.sign(
    verb: "get",
    path: "/orders",
    expiry: 1_700_000_000,
    nonce: "a-nonce",
    query: "a=1"
  )
```

## How does it work

This is intended for a secure discussion between 2 servers and not something in a browser as the secret key must be stored and used on both sides (and you don't want to send the secret key in the browser).

Both servers will have the same secret key. The sender will generate a signature matching the HTTP request it will be sending (the verb, the path, the query and the body, with an expiry and a nonce) and add it to the request in designated headers. The receiver will generate the same signature from the HTTP request it has received and will compare it with the signature in the header.

The comparison will be done in constant time (i.e. secure) because both strings will be hexdigests from a HMAC with the same algorithm.

The exact byte format is described in [docs/SPEC.md](docs/SPEC.md), with golden vectors. This is the contract another implementation (the TypeScript one for example) will have to reproduce exactly.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb` and the CHANGELOG, then push to `main` : the gem is published to [rubygems.org](https://rubygems.org) through trusted publishing.

Every commit/push is checked by overcommit. You should (must) activate overcommit by using `overcommit -i` post installation.

Tools used in dev:

- Rubocop
- Syntax Tree
- Sorbet
- RSpec

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zaratan/m2m_keygen_ruby. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/zaratan/m2m_keygen_ruby/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the M2mKeygen project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/zaratan/m2m_keygen_ruby/blob/main/CODE_OF_CONDUCT.md).
