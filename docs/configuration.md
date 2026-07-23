# Configuration

The tokenizer is customizable via a `Charset` object or constructor options.
Defaults reproduce the built-in behavior exactly.

## Two API Shapes

### 1. Charset object (for tweaking multiple fields)

```ruby
charset = Tokenzr::Charset.default
charset.lone = charset.lone.delete('`')  # remove backtick from lone
charset.quotes = charset.quotes + '`'    # add backtick to quotes
tokenizer = Tokenzr::Tokenizer.new(charset:)
```

### 2. Constructor options (for one-off overrides)

```ruby
tokenizer = Tokenzr::Tokenizer.new(quotes: "\"'`", lone: '()[]<>{}!#$%&*+,-./:;=?@\\^|~')
```

Options merge **over** the default charset — you only specify the fields you
want to change. Both shapes can be combined: pass a `charset:` and individual
overrides; the overrides win per-field.

## Charset Fields

| Field       | Type     | Default                                              | Purpose                              |
|-------------|----------|------------------------------------------------------|--------------------------------------|
| `text`      | `String` | `a-zA-Z_`                                            | Identifier start + continuation chars |
| `digits`    | `String` | `0-9`                                                | Number start + continuation chars     |
| `lone`      | `String` | `()[]<>{}!#$%&*+,-./:;=?@\^`&#124;~`                | Single-char symbols                   |
| `space`     | `String` | ` \t\n\r\v\f`                                        | Whitespace (skipped, no tokens)       |
| `quotes`    | `String` | `"'`                                                 | String delimiters                     |
| `operators` | `Array`  | `[]`                                                 | Multi-char symbols (see below)        |

All string fields accept a plain `String` of characters; internally they're
converted to `Set` objects for O(1) lookup via `Charset#to_sets`.

## Conflict Validation

The five character sets (`text`, `digits`, `lone`, `space`, `quotes`) must be
**pairwise disjoint** — a char cannot belong to two sets. This is validated at
construct time (in `Tokenizer.new`), not lazily:

```ruby
# Raises immediately:
Tokenzr::Tokenizer.new(text: 'ab1', digits: '123')
# => Tokenzr::ConfigurationError: Charset conflict: "1" in digits, text
```

The error message names each conflicting char and the sets it appears in.

**Why:** without disjoint sets, the dispatch order would silently determine
which set "wins" for a shared char, which is surprising and bug-prone. Failing
loud at construct forces the user to make an explicit choice.

## Operator Validation

Multi-char operators (the `operators` array) have a separate validation rule:
**every character in every operator must be in the `lone` charset.**

```ruby
# Raises immediately:
Tokenzr::Tokenizer.new(operators: ['==D'])
# => Tokenzr::ConfigurationError: Operator "==D" contains chars not in the lone charset: "D"
```

**Why:** the operator matcher only runs when the parse loop reaches the `lone`
branch (after quotes/space/digits/text). If an operator contained a text char
like `D`, the `D` would be consumed as text before the operator matcher ever
runs — so the operator would never match, OR worse, it would greedily eat a
text char when it does run (e.g. `==D` swallowing the `D` from `A==D`).

Requiring all operator chars to be in `lone` ensures operators only use
symbol characters, which is the realistic use case anyway.

## Operator Matching

Operators are indexed by first char at construct time, sorted **longest-first**
per group. When the parse loop hits a `lone` char, `match_operator`:

1. Looks up candidates starting with that char
2. Tries each candidate (longest first), consuming ahead and comparing
3. On a full match → emits one `:lone` token with the full operator string
4. On a mismatch → pushes back consumed chars (with positions) and tries next
5. If no candidate matches → falls through to a single `:lone` token

This is standard **maximal munch** — greedy left-to-right matching. Examples
with `operators: ['==', '===']`:

- `===` → `:lone` `===` (longest wins)
- `==` → `:lone` `==`
- `=` → `:lone` `=` (no operator matches, single lone)

## Immutability After Construct

`Tokenizer.new` **dups** the charset internally. Mutating the `Charset` object
you passed in after construction has no effect on the tokenizer:

```ruby
charset = Tokenzr::Charset.default
tokenizer = Tokenzr::Tokenizer.new(charset:)
charset.quotes = ''    # mutate after construct — no effect
tokenizer.parse('"hi"') # still works, quotes unchanged
```

This prevents a class of bugs where a shared charset object is mutated and
existing tokenizers silently change behavior.

## Default Charset Reference

The exact defaults, for reference:

```ruby
Tokenzr::Charset.default
# text:     "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
# digits:   "0123456789"
# lone:     "()[]<>{}!#$%&*+,-./:;=?@\\^`|~"
# space:    " \t\n\r\v\f"
# quotes:   "\"'"
# operators: []
```

## What's NOT Configurable (Yet)

These are deferred — see [design-decisions.md](design-decisions.md):

- **Comments** — `#...` or `//...` line comments, `/* ... */` block comments
- **Number separators** — underscores in numbers like `1_000_000`
- **Keyword classification** — that's parser territory, not the tokenizer's job
- **Escape interpretation** — `\n` → newline is semantics, not tokenizing
- **Whitespace as tokens** — the skip-whitespace default is what most users want
