# Architecture

## File Layout

```
lib/
├── tokenzr.rb              # loader — requires all sub-files
└── tokenzr/
    ├── version.rb          # module Tokenzr; VERSION = '0.1.0'; end
    ├── error.rb            # Error, UnknownCharError, UnterminatedStringError
    ├── charset.rb          # Charset + ConfigurationError + Conflict struct
    ├── token.rb            # Token (immutable value object)
    └── tokenizer.rb        # Tokenizer (the parser, all the logic)
```

## Require Graph

```
lib/tokenzr.rb
  ├── lib/tokenzr/version.rb
  ├── lib/tokenzr/error.rb      (no internal deps)
  ├── lib/tokenzr/charset.rb    → error.rb, 'set'
  ├── lib/tokenzr/token.rb      (no internal deps)
  └── lib/tokenzr/tokenizer.rb  → error.rb, charset.rb, token.rb, 'set'
```

No circular dependencies. Each sub-file can be required on its own (e.g.
`require 'tokenzr/token'` works). Users only need `require 'tokenzr'` which
loads everything via the loader.

## Class Responsibilities

### `Tokenzr::Token` (`lib/tokenzr/token.rb`)

An immutable value object with four read-only attributes:

| Attribute | Type      | Description                                   |
|-----------|-----------|-----------------------------------------------|
| `content` | `String`  | The raw text of the token (e.g. `"abc"`, `"=="`, `'"hi"'`) |
| `type`    | `Symbol`  | One of `:text`, `:number`, `:string`, `:lone` |
| `line`    | `Integer` | 1-based line number of the token's first character |
| `column`  | `Integer` | 1-based column number of the token's first character |

`Token` has no behavior beyond construction and reading — it's pure data. The
constructor accepts all four as optional keyword-free args (positional, so
`Token.new('x', :lone, 1, 5)` works).

### `Tokenzr::Charset` (`lib/tokenzr/charset.rb`)

A configurable container for the five character sets (and operators) that
control classification. See [configuration.md](configuration.md) for details.

- String attributes: `text`, `digits`, `lone`, `space`, `quotes`
- Array attribute: `operators` (multi-char symbols, default `[]`)
- `.default` — returns a fresh mutable copy of the built-in defaults
- `#to_sets` — converts the strings to a hash of `Set` objects (for O(1) lookup)
- `#conflicts` — returns an array of `Conflict` structs for any char in 2+ sets

### `Tokenzr::Tokenizer` (`lib/tokenzr/tokenizer.rb`)

The parser. Owns all tokenization logic. Key internals:

| Internal              | Purpose                                                      |
|-----------------------|--------------------------------------------------------------|
| `@charset`            | The frozen `Charset` (dup'd on construct, not the user's)    |
| `@charset.to_sets`    | Memoized via `text_chars`/`digit_chars`/etc. for O(1) lookup |
| `@operators_by_first` | Hash mapping first-char → operators (longest-first), built at construct |
| `@pushback`           | Stack of `[char, line, col]` for operator-match rewinding     |
| `@line`/`@column`     | Position of the **next** char to read (1-based)              |
| `@cur_line`/`@cur_col`| Position of the **last** char consumed                       |

### Errors (`lib/tokenzr/error.rb`, `lib/tokenzr/charset.rb`)

```
Tokenzr::Error                      (StandardError)
├── UnknownCharError               — non-ASCII or control char in input
├── UnterminatedStringError        — unclosed quote in input
└── ConfigurationError             — invalid charset or operators (defined in charset.rb)
```

All tokenzr errors inherit from `Tokenzr::Error`, so rescuing that catches
everything.

## Data Flow

```
Tokenizer.new(charset: ...)
  │
  ├── merge_overrides(base, overrides) → Charset
  ├── Charset#conflicts → [] or raise ConfigurationError
  ├── validate_operators! → nil or raise ConfigurationError
  └── build_operator_index → @operators_by_first (longest-first)
      │
Tokenizer#parse(content)
  │
  ├── content.each_char → Enumerator
  ├── reset @line, @column, @cur_line, @cur_col, @pushback
  │
  └── loop: next_char(enum) → chr
        ├── string_quotes? → read_string → Token(:string)
        ├── space_chars?   → skip (flush current_token)
        ├── digit_chars?   → continue text OR read_number → Token(:number) | [tokens]
        ├── text_chars?    → accumulate into current_token (:text)
        ├── lone_chars?    → match_operator OR emit single Token(:lone)
        └── else           → raise UnknownCharError
```

## Position Tracking

`next_char` is the single point where position advances. It records the
consumed char's position into `@cur_line`/`@cur_col`, then advances `@line`/
`@column` (the "next" position). `\n` resets column to 1 and increments line;
all other chars (including tabs, multi-byte) count as 1 column.

`peek_char` does NOT advance position (uses `Enumerator#peek`). The pushback
stack restores both the char AND its original position when rewinding.

Tokens snapshot their start position from `@cur_line`/`@cur_col` at creation
time. Multi-char tokens (numbers, strings, operators) report the position of
their **first** character.

## Not Reentrant

`parse` uses instance variables (`@line`, `@column`, `@pushback`, etc.) for
state, so a single `Tokenizer` instance is **not reentrant** — do not call
`parse` concurrently on the same instance (e.g. from multiple threads).
Sequential calls are fine; each call resets the position state at the top.

Create a new `Tokenizer` per thread, or per concurrent parse, if you need
concurrency. The charset validation and operator index are built once at
construction and are safe to share across instances.
