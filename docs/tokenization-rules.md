# Tokenization Rules

This document describes exactly how `Tokenizer#parse` classifies characters
and builds tokens. The rules here are pinned by tests in `spec/tokenzr/`.

## Dispatch Order (Precedence)

The parse loop checks each character against the charsets in this order:

1. **Quotes** — if the char is in `quotes`, start a string (flush current token)
2. **Space** — if the char is in `space`, skip it (flush current token)
3. **Digits** — if the char is in `digits`, either continue a text token or start a number
4. **Text** — if the char is in `text`, accumulate into the current text token
5. **Lone** — if the char is in `lone`, try operator match or emit a single lone token
6. **Else** — raise `UnknownCharError`

This order matters. Quotes and space are checked before digits/text, so a `"`
always starts a string even if it appeared in other sets (though the disjoint
validation prevents that). Digits are checked before text, but the digit branch
has a special case: if there's a current `:text` token, the digit **continues**
it rather than starting a number.

## Token Types

### `:text` — Identifiers

- **Start:** any char in `text` (default: `a-z A-Z _`)
- **Continue:** any char in `text` or `digits`
- A digit after text continues the text token: `abc123` → one `:text` token
- A letter after a number starts a new text token: `123abc` → `:number` `123`, `:text` `abc`
- Underscores are text chars, so `_foo` and `___` are valid identifiers
- Default text charset is ASCII only. Unicode identifiers (e.g. `café`, hiragana)
  raise `UnknownCharError` unless the user adds them to the `text` charset.

### `:number` — Numeric Literals

Three formats, all emitted as `:number`:

**Integers** — a run of digits: `123`, `007`, `00`

**Floats** — digits, `.`, digits. The `.` only joins the number when followed by
a digit:
- `1.5` → one `:number`
- `1.` → `:number` `1` + `:lone` `.` (no fractional digit)
- `.5` → `:lone` `.` + `:number` `5` (leading dot isn't a number start)
- `1.5.6` → `1.5` `.` `5` (second dot is a lone token)

**Hex** — `0x` or `0X` followed by at least one hex digit `[0-9a-fA-F]`:
- `0x1F`, `0X1F`, `0xff` → one `:number`
- `0x` with no hex digit → `:number` `0` + `:text` `x` (graceful fallback)
- `0xG` → `:number` `0` + `:text` `x` + `:text` `G` (fallback)
- Only recognized after a **single** `0`: `00x5` → `:number` `00` + `:text` `x5`

**Scientific** — digits, `e`/`E`, optional `+`/`-`, digits:
- `1e10`, `1E10`, `1e+10`, `1e-10` → one `:number`
- `1.5e3`, `1.5e-3` → one `:number` (works after floats)
- `1e` with no exponent → `:number` `1` + `:text` `e` (graceful fallback)
- `1e-` with no digits after sign → `:number` `1` + `:text` `e` + `:lone` `-`

**Fallback behavior:** invalid number patterns don't raise — they fall back to
the number token plus leftover chars as their own tokens. This keeps the
tokenizer usable for edge cases without raising. See [rough-edges.md](rough-edges.md).

### `:string` — Quoted Strings

- **Delimiters:** any char in `quotes` (default: `"` and `'`)
- **Content includes the quotes** — `"hi"` produces a token with content `"hi"`
  (5 chars), not `hi` (3 chars)
- **Spaces inside strings are preserved** — `"a b"` is one token, not split
- **Newlines/tabs inside strings are preserved** — a string can span multiple lines
- **Unicode inside strings is preserved** — `"café"` is one token

**Escape rules** (minimal, per-quote):
- A backslash before the **matching** quote escapes it: `\"` in `"..."`, `\'` in `'...'`
- A backslash before any **other** char is literal: `"a\nb"` is the 6 chars `"a\nb"` (not a newline)
- A single quote is literal inside a double-quoted string and vice versa
- A backslash before a backslash (`"\\"`) is an escaped backslash — one literal `\`
- Escape sequences like `\n`, `\t` are **not interpreted** — they stay as `\` + `n`.
  Interpreting escapes is the parser's job, not the tokenizer's.

**Errors:**
- Unterminated string → `UnterminatedStringError` (e.g. `"hello` with no closing quote)
- Backslash escaping the final quote → unterminated (e.g. the 3-char `"\`)

### `:lone` — Single-Character Symbols

Any char in `lone` that isn't consumed as part of a multi-char operator. Default
lone set: all printable ASCII symbols (`()[]<>{}!#$%&*+,-./:;=?@\^`|~`).

Each lone char is its own token: `()` → two `:lone` tokens `(` and `)`.

### Multi-Char Operators (also `:lone`)

When `operators` is configured (default `[]`), the tokenizer tries to match a
multi-char operator before emitting a single lone token:

- Operators are indexed by first char, sorted **longest-first** per group
- Matching is **greedy left-to-right** (maximal munch): `===` with operators
  `['==', '===']` → one `:lone` `===`, not `==` + `=`
- On a failed match, consumed chars are pushed back (with their positions) and
  the next candidate is tried; if no candidate matches, a single `:lone` is emitted
- Operators emit as `:lone` type with multi-char content (e.g. `:lone` `"=="`)
- All chars in an operator must be in the `lone` charset (validated at construct)

See [configuration.md](configuration.md) for operator setup.

## Whitespace Handling

Chars in `space` (default: space, tab `\t`, newline `\n`, carriage return `\r`,
vertical tab `\v`, form feed `\f`) are **skipped** — they do not produce tokens.

- Consecutive spaces collapse: `a    b` → two tokens `a`, `b` (no space tokens)
- Leading/trailing spaces are trimmed: `  abc  ` → one token `abc`
- **Bare `\r` does not reset the column counter** — only `\n` does. CRLF (`\r\n`)
  works because `\r` is skipped and `\n` resets. Classic-Mac (`\r` only) files
  will have incorrect column numbers after each `\r`. See rough-edges.md.
- BOM (`\uFEFF`) is **not** whitespace — it raises `UnknownCharError`.

## Position Tracking

Every token records the `line` and `column` of its **first** character:

- 1-based (first char of input is line 1, column 1)
- Each char counts as 1 column, including tabs (no tab expansion)
- `\n` resets column to 1 and increments line
- Multi-line strings report the position of the opening quote
- Multi-char operators report the position of their first char
- Fallback tokens (from failed hex/fraction/exponent) each record their own position

## Empty / Edge Inputs

- `parse('')` → `[]`
- `parse('   ')` (only spaces) → `[]`
- `parse("\t\n\v\f")` (only whitespace) → `[]`
- `parse(nil)` → raises `NoMethodError` (no guard — string input is the contract)
