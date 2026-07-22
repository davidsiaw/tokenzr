# frozen_string_literal: true

require_relative 'lib/tokenzr/version'

Gem::Specification.new do |spec|
  spec.name          = 'tokenzr'
  spec.version       = Tokenzr::VERSION
  spec.authors       = ['David Siaw']
  spec.email         = ['874280+davidsiaw@users.noreply.github.com']

  spec.summary       = 'Tokenzr gem'
  spec.description   = 'Tokenizer for most common cases of tokenization'
  spec.homepage      = 'https://github.com/davidsiaw/tokenzr'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.0')

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/davidsiaw/tokenzr'
  spec.metadata['changelog_uri'] = 'https://github.com/davidsiaw/tokenzr'
  spec.metadata['documentation_uri'] = 'https://davidsiaw.github.io/tokenzr'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = Dir['{exe,data,lib}/**/*'] + %w[Gemfile tokenzr.gemspec]
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
