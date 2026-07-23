# Examples

Ready-to-use snippets for common customizations. Each follows the pattern:
grab the default charset, modify the relevant fields (taking care to remove
chars from their original set when moving them), construct, parse.

These mirror the tests in `spec/tokenzr/customization_examples_spec.rb`.

## Kebab-Case Identifiers

Move `-` from `lone` to `text` so `my-var` is one token instead of `my` `-` `var`:

```ruby
charset = Tokenzr::Charset.default
charset.lone = charset.lone.delete('-')
charset.text = charset.text + '-'
tokenizer = Tokenzr::Tokenizer.new(charset:)

tokenizer.parse('my-kebab-variable = 42')
# => [:text "my-kebab-variable", :lone "=", :number "42"]
```

## Backtick-Quoted Strings

Move `` ` `` from `lone` to `quotes` so `` `hello` `` is a string:

```ruby
charset = Tokenzr::Charset.default
charset.lone = charset.lone.delete('`')
charset.quotes = charset.quotes + '`'
tokenizer = Tokenzr::Tokenizer.new(charset:)

tokenizer.parse('let x = `hello world`')
# => [:text "let", :text "x", :lone "=", :string "`hello world`"]
```

## Ruby-Style Method Names (? and ! suffixes)

Move `?` and `!` from `lone` to `text` so `empty?` and `done!` are single tokens:

```ruby
charset = Tokenzr::Charset.default
charset.lone = charset.lone.delete('!').delete('?')
charset.text = charset.text + '!?'
tokenizer = Tokenzr::Tokenizer.new(charset:)

tokenizer.parse('if empty? then done! end')
# => [:text "if", :text "empty?", :text "then", :text "done!", :text "end"]
```

## Multi-Char Operators

Add `==`, `!=`, `<=`, `>=`, `=>`, `&&`, `||`, `->` as single tokens:

```ruby
tokenizer = Tokenzr::Tokenizer.new(operators: ['==', '!=', '<=', '>=', '=>', '&&', '||', '->'])

tokenizer.parse('if a == b && c != d then e -> f end')
# => [:text "if", :text "a", :lone "==", :text "b", :lone "&&",
#     :text "c", :lone "!=", :text "d", :text "then",
#     :text "e", :lone "->", :text "f", :text "end"]
```

Operators must only use chars from the `lone` charset (validated at construct).
Matching is greedy longest-first: `===` with `operators: ['==', '===']` →
`:lone "==="`.

## Hex-Digit Language

Make `a-f` digits (for a hex-focused language), removing them from text to
avoid conflicts:

```ruby
charset = Tokenzr::Charset.default
charset.digits = '0123456789abcdef'
charset.text = charset.text.delete('abcdef')
tokenizer = Tokenzr::Tokenizer.new(charset:)

tokenizer.parse('ff + 1a')
# => [:number "ff", :lone "+", :number "1a"]
```

## Extra Whitespace (Non-Breaking Space)

Add U+00A0 to the space set:

```ruby
charset = Tokenzr::Charset.default
charset.space = charset.space + "\u00A0"
tokenizer = Tokenzr::Tokenizer.new(charset:)

tokenizer.parse("a\u00A0b")
# => [:text "a", :text "b"]
```

## Hiragana Identifiers

Add hiragana to the text charset for Japanese identifiers:

```ruby
charset = Tokenzr::Charset.default
charset.text = charset.text + 'ぁあぃいぅうぇえぉおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん'
tokenizer = Tokenzr::Tokenizer.new(charset:)

tokenizer.parse('hello こんにちは world')
# => [:text "hello", :text "こんにちは", :text "world"]
```

## CSV Parsing

A CSV-focused tokenizer: all printable chars are text (except `"` and `,`),
comma is the only lone token, double-quote for quoted fields, no whitespace
skipping (so spaces inside fields are preserved):

```ruby
text_chars = (32..126).map(&:chr).join.delete('"').delete(',')
charset = Tokenzr::Charset.new(
  text: text_chars,
  digits: '',
  lone: ',',
  space: '',
  quotes: '"'
)
tokenizer = Tokenzr::Tokenizer.new(charset:)

tokenizer.parse('"hello, world",foo,123')
# => [:string "\"hello, world\"", :lone ",", :text "foo", :lone ",", :text "123"]
```

Note: `123` is `:text` here, not `:number`, because `digits` is empty.

## Stripped-Down Lone Set (Only Parens)

Reduce `lone` to just `()` — everything else that was a lone char now raises
`UnknownCharError`:

```ruby
charset = Tokenzr::Charset.default
charset.lone = '()'
tokenizer = Tokenzr::Tokenizer.new(charset:)

tokenizer.parse('foo(bar)')
# => [:text "foo", :lone "(", :text "bar", :lone ")"]

tokenizer.parse('a+b')
# => raises Tokenzr::UnknownCharError (Unknown character: "+")
```

## Building from Options (No Charset Object)

For one-off customizations, pass options directly:

```ruby
tokenizer = Tokenzr::Tokenizer.new(
  text: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-',
  lone: '()[]<>{}!#$%&*+,./:;=?@\\^`|~'
)

tokenizer.parse('snake_case and kebab-case')
# => [:text "snake_case", :text "and", :text "kebab-case"]
```

Options merge over the default charset — unspecified fields keep their defaults.

## Inspecting Token Positions

Every token has `line` and `column` (1-based, position of the first char):

```ruby
tokenizer = Tokenzr::Tokenizer.new
tokens = tokenizer.parse("foo(123 \"bar baz\")\n  0x1F 1.5e3")

tokens.each do |tok|
  puts "#{tok.line}:#{tok.column} #{tok.type} #{tok.content.inspect}"
end
# 1:1 text "foo"
# 1:4 lone "("
# 1:5 number "123"
# 1:9 string "\"bar baz\""
# 1:18 lone ")"
# 2:3 number "0x1F"
# 2:8 number "1.5e3"
```
