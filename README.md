# Tokenzr

Tokenzr is a small, dependency-free Ruby tokenizer for the common cases. It breaks a string into tokens without needing a grammar or a hand-written scanner int identifiers, numbers (including floats, hex, and scientific notation), quoted strings, and symbols all work out of the box.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tokenzr'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install tokenzr

## Usage

```ruby
require 'tokenzr'

tokenizer = Tokenzr::Tokenizer.new
tokens = tokenizer.parse('foo(123 "bar baz") 0x1F 1.5e3')

tokens.each do |tok|
  puts "#{tok.line}:#{tok.column} #{tok.type} #{tok.content.inspect}"
end
```

Each `Token` has `content`, `type`, `line`, and `column`. Token types are:

- `:text` — identifiers: start with a letter or `_`, continue with letters, digits, or `_`
- `:number` — integers, floats (`1.5`), hex (`0x1F`), and scientific notation (`1e10`, `1.5e-3`)
- `:string` — single- or double-quoted strings, content includes the quotes
- `:lone` — any other printable ASCII symbol (parentheses, operators, punctuation, etc.)

Whitespace is skipped and does not produce tokens. Inside a string, a backslash escapes the matching quote (`\"` in double-quoted, `\'` in single-quoted); any other character after a backslash is literal. Unknown characters (non-ASCII, control bytes) raise `Tokenzr::UnknownCharError`. Unterminated strings raise `Tokenzr::UnterminatedStringError`. Both are subclasses of `Tokenzr::Error`.

## Documentation

Detailed documentation is here: https://davidsiaw.github.io/tokenzr/

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/davidsiaw/tokenzr. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/davidsiaw/tokenzr/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Tokenzr project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/davidsiaw/tokenzr/blob/master/CODE_OF_CONDUCT.md).
