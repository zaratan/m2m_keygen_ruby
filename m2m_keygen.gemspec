# frozen_string_literal: true

require_relative 'lib/m2m_keygen/version'

Gem::Specification.new do |spec|
  spec.name = 'm2m_keygen'
  spec.version = M2mKeygen::VERSION
  spec.authors = ['Denis <Zaratan> Pasin']
  spec.email = ['zaratan@hey.com']

  spec.summary = 'Secure M2M key generator'
  spec.description =
    'Secure M2M key generator for Ruby. Generates secure keys for M2M communication in REST APIs.'
  spec.homepage = 'https://github.com/zaratan/m2m_keygen_ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'rubygems_mfa_required' => 'true',
  }

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(__dir__) do
      `git ls-files -z`.split("\x0")
        .reject do |f|
          (f == __FILE__) ||
            f.match(
              %r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)},
            )
        end
    end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rack', '>= 2.2', '< 4.0'
  spec.add_dependency 'sorbet-runtime', '>= 0.5'
  spec.add_dependency 'zeitwerk', '>= 2.6', '< 3.0'
end
