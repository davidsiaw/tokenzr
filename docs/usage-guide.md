# Usage Guide

How to use tokenzr from the user's side. For installation, see the
[README](../README.md). For maintainer docs, see the
[docs README](README.md).

## The Basics

```ruby
require 'tokenzr'

tokenizer = Tokenzr::Tokenizer.new
tokens = tokenizer.parse('foo(123 "bar baz") 0x1F 1.5e3')

tokens.each do |tok|
  puts "#{tok.line}:#{tok.column} #{tok.type} #{tok.content.inspect}"
end
```

Output:

```
1:1 text "foo"
1:4 lone "("
1:5 number "123"
1:9 string "\"bar baz\""
1:18 lone ")"
1:20 number "0x1F"
1:25 number "1.5e3"
```

That's the whole API for the default behavior. `parse` takes a string and
returns an array of `Tokenzr::Token` objects.

## The Token Object

Every token has four read-only attributes:

| Attribute | What it is                                              |
|-----------|---------------------------------------------------------|
| `content` | The raw text of the token (e.g. `"foo"`, `"=="`, `'"hi"'`) |
| `type`    | `:text`, `:number`, `:string`, or `:lone`               |
| `line`    | 1-based line number where the token starts              |
| `column`  | 1-based column number where the token starts            |

Tokens are immutable — once created, they don't change. You can safely store
and compare them.

## Token Types

| Type     | What it captures                                              | Examples                     |
|----------|---------------------------------------------------------------|------------------------------|
| `:text`  | Identifiers: start with letter/`_`, continue with alphanum/`_` | `foo`, `bar_baz`, `x1`      |
| `:number`| Integers, floats, hex, scientific notation                   | `42`, `1.5`, `0xFF`, `1e10` |
| `:string`| Single- or double-quoted strings (quotes included in content) | `"hi"`, `'hi'`              |
| `:lone`  | Any other printable ASCII symbol (parens, operators, etc.)   | `(`, `)`, `=`, `+`, `==`    |

## Common Patterns

### Filter by type

```ruby
tokens = tokenizer.parse(source)

identifiers = tokens.select { |t| t.type == :text }
numbers      = tokens.select { |t| t.type == :number }
strings      = tokens.select { |t| t.type == :string }
```

### Get just the contents

```ruby
words = tokenizer.parse(source).map(&:content)
```

### Find a token by position

```ruby
token = tokens.find { |t| t.line == 3 && t.column == 10 }
```

### Reconstruct source (lossless for non-whitespace)

```ruby
# Note: whitespace between tokens is not preserved in the token stream.
# Only join with a separator if you don't need exact reconstruction.
tokenizer.parse('a b c').map(&:content).join(' ')
# => "a b c"
```

### Count tokens

```ruby
tokens.length
# Or by type:
tokens.tally { |t| t.type }  # Ruby 3.4+  => {:text=>3, :lone=>2, ...}
```

### Check for a specific token

```ruby
has_return = tokenizer.parse(source).any? { |t| t.type == :text && t.content == 'return' }
```

### Iterate with lookahead

```ruby
tokens.each_with_index do |tok, i|
  next_tok = tokens[i + 1]
  puts "#{tok.content} is followed by #{next_tok&.content}"
end
```

## Handling Errors

```ruby
begin
  tokens = tokenizer.parse(source)
rescue Tokenzr::UnknownCharError => e
  puts "Bad character: #{e.message}"          # e.g. Unknown character: "€"
rescue Tokenzr::UnterminatedStringError => e
  puts "String not closed: #{e.message}"      # e.g. Unterminated string: "
rescue Tokenzr::Error => e
  puts "Some tokenzr error: #{e.message}"     # catch-all (superclass of both)
end
```

`Tokenzr::Error` is the parent of all tokenzr errors, so rescuing it catches
everything. `Tokenzr::ConfigurationError` (from bad charsets) is also a
subclass, but that's raised at `Tokenizer.new`, not at `parse`.

## When to reach for custom charsets

The default charset handles a lot, but you'll want to customize when:

- **Your identifiers use `-`** (kebab-case, CSS, lisp) → move `-` from `lone` to `text`
- **Your identifiers use `?` or `!`** (Ruby method names) → move them to `text`
- **You want backtick strings** (JS template literals, shell) → move `` ` `` to `quotes`
- **You need multi-char operators** (`==`, `!=`, `->`) → add them to `operators`
- **You're tokenizing something weird** (CSV, data files) → rebuild the charset

See [examples.md](examples.md) for ready-to-copy snippets for each of these,
and [configuration.md](configuration.md) for the full config reference.

## When NOT to use tokenzr

- **You need a real parser** — tokenzr doesn't parse grammar, just tokenize.
  If you need ASTs, tree-sitter, racc, or parslet are better fits.
- **You need comments stripped** — not built in yet (deferred feature). You'd
  preprocess the input to remove comments first.
- **You need interpreted escape sequences** — `"a\nb"` stays literal. The
  tokenizer preserves raw content; interpreting escapes is your job.
- **You need whitespace tokens** — whitespace is always skipped. If you need
  it, tokenzr isn't the right tool.
- **Your input is huge (MBs)** — the string-building is O(n²) per token due
  to `content += chr`. Fine for most source files; slow for very long tokens.

## Tips

- **One tokenizer, many parses** — a `Tokenizer` instance is reusable for
  sequential `parse` calls. Don't create a new one per parse unless you need
  different charsets.
- **Don't share a tokenizer across threads** — `parse` uses instance vars for
  position state, so it's not reentrant. Create one per thread.
- **Charset is dup'd on construct** — mutating the `Charset` you passed to
  `new` after construction has no effect. The tokenizer has its own copy.
- **Positions are 1-based** — first char is line 1, column 1. Matches how
  editors and error messages number lines.
- **Tabs count as 1 column** — there's no tab expansion. If you need
  tab-stops, compute them from the column and your tab width.
