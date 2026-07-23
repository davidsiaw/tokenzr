# Design Decisions

A record of why things are the way they are — for future maintainers who might
otherwise "fix" something that was deliberate.

## Why a tokenizer without a grammar?

**Decision:** Tokenzr is a grab-and-go tokenizer for the common cases, not a
grammar-driven scanner generator.

**Why:** Writing a scanner by hand or defining a grammar is overkill when you
just need to break `"foo(123 \"bar\")"` into tokens. Tokenzr handles
identifiers, numbers, strings, and symbols out of the box so you can get
started in one line. For complex languages, reach for a real parser generator.

## Why are digits in identifiers but not vice versa?

**Decision:** `abc123` is one `:text` token, but `123abc` is `:number` `123`
then `:text` `abc`.

**Why:** This matches the conventional identifier rule `[a-zA-Z_][a-zA-Z0-9_]*`
— identifiers start with a letter/underscore and continue with alphanumerics.
A number can't start an identifier, but once an identifier has started, digits
are valid continuation characters. The dispatch order (digits checked before
text, with a "continue current text token" special case) implements this.

## Why do invalid number patterns fall back instead of raising?

**Decision:** `0x` (no hex digits) → `0` number + `x` text. `1e` (no exponent)
→ `1` number + `e` text. `1e-` → `1` number + `e` text + `-` lone.

**Why:** Raising on `0x` would make the tokenizer brittle — a user tokenizing
text that happens to contain `0x` (e.g. a tweet) would get errors. Falling back
keeps the tokenizer usable for arbitrary text. The number reader tries to be
greedy but bails gracefully when the pattern doesn't hold, emitting the consumed
chars as their natural token types.

**Trade-off:** `0x1e5` is a hex number (the `e` is a hex digit, not an
exponent). This is correct but surprising if you expected scientific notation
inside hex. There's no exponent in hex — that's the rule. See
[rough-edges.md](rough-edges.md).

## Why does `1.5` work but `1.` doesn't?

**Decision:** `1.5` → one number. `1.` → `1` number + `.` lone. `1.e5` → `1`
+ `.` + `e5` text.

**Why:** The fraction rule requires a digit after the `.`. This matches most
real languages (a trailing dot is usually a method call or range operator, not
a float). Without this rule, `1.` would ambiguously be `1.0` or `1` + `.`, and
we chose the less surprising split. If you want `1.` to be a float, the parser
layer can reassemble it.

## Why is `.` (dot) a lone token, not an operator?

**Decision:** `.` is in the default `lone` set, and `1.5` is special-cased
inside `read_number` (not via the operators mechanism).

**Why:** The `.` in a float is part of the number syntax, not a standalone
operator. Handling it inside `read_number` (with peek-ahead) is cleaner than
trying to make the operators mechanism do context-dependent matching. The
operators system is for context-free multi-char symbols like `==`, `!=`, `->`.

## Why is backslash both a lone token AND an escape char?

**Decision:** Outside a string, `\` is a `:lone` token. Inside a string, `\`
is the escape character.

**Why:** These are two separate code paths (`parse`'s dispatch vs
`read_string`'s loop). There's no conflict because the string reader takes over
completely once a quote is seen. A backslash outside a string is just a symbol
— some languages use it (e.g. line continuation, namespace separators). If you
don't want backslash as a lone token, remove it from the `lone` charset and it
will raise `UnknownCharError` outside strings.

## Why are escape sequences not interpreted?

**Decision:** `"a\nb"` produces a `:string` token with the literal 6 characters
`"a\nb"` (backslash + n), not `"a` + newline + `b"`.

**Why:** Interpreting `\n` as a newline is **semantics**, not tokenization. The
tokenizer's job is to identify the string boundaries and content; turning
escape sequences into their actual bytes is the parser's/interpreter's job.
This keeps the tokenizer simple and lossless — the raw content is preserved
for whatever the consumer wants to do with it.

## Why is `\r` not treated as a newline?

**Decision:** Only `\n` resets the column counter and increments the line. `\r`
is skipped as whitespace but doesn't reset the column.

**Why:** Modern files use `\n` (Unix) or `\r\n` (Windows). With CRLF, `\r` is
skipped and `\n` resets — works correctly. Bare `\r` (classic Mac, pre-OSX) is
extremely rare today. Treating `\r` as a newline would require deciding whether
`\r\n` is one newline or two, which is fiddly. The current behavior is wrong for
bare-`\r` files but correct for everything else. If you need classic-Mac
support, preprocess to convert `\r` to `\n` before parsing.

## Why is BOM not whitespace?

**Decision:** `\uFEFF` (UTF-8 BOM) raises `UnknownCharError`.

**Why:** The maintainer considers BOM "not a real thing" — it's an editor
artifact, not a meaningful character. If your input has a BOM, strip it before
parsing. (We briefly added BOM to the space set and then removed it per the
maintainer's call.)

## Why is `parse` not reentrant?

**Decision:** `parse` uses instance variables (`@line`, `@column`, `@pushback`)
for position and pushback state. Concurrent `parse` calls on the same instance
will corrupt each other.

**Why:** Using instance vars avoids passing a state object through every
internal method (`next_char`, `read_number`, `match_operator`, etc.), which
would make the code significantly uglier. The trade-off is that concurrency
requires creating a new `Tokenizer` per thread — but the charset validation and
operator index (the expensive parts) are done once at construction and are safe
to share. Creating a `Tokenizer` is cheap.

## Why the polymorphic return from `read_number`?

**Decision:** `read_number` returns either a `Token` (normal case) or an
`Array` of `Token`s (fallback case). `parse` checks `is_a?(Array)`.

**Why:** The fallback cases (failed hex prefix, failed fraction, failed
exponent) need to emit multiple tokens (the number plus the leftover chars).
Returning an array is simpler than introducing a pushback mechanism for the
number reader (which would interact with the operator pushback queue). It's a
small smell — if a sixth fallback case ever appears, refactor to always return
an array.

## Why are operators `:lone` type, not a new `:operator` type?

**Decision:** Multi-char operators like `==` emit as `:lone` with content
`"=="`, not a new `:operator` type.

**Why:** Backward compatibility. Consumers that switch on `token.type` don't
need to know about operators — they just see `:lone` with a multi-char content.
The `:lone` type already means "a symbol token", and `==` is a symbol. Adding
a new type would break existing consumers for no semantic gain. If you need to
distinguish operators from single chars, check `token.content.length > 1`.

## Deferred Features

These were considered and explicitly deferred:

- **Comments** (`#...`, `//...`, `/* ... */`) — feels like preprocessor work;
  deferred. Would add a `comments:` config option.
- **Number separators** (`1_000_000`) — would be a parsing rule in `read_number`,
  not a charset change. Adding `_` to `digits` would break identifiers.
- **Multi-char operators** — implemented! See [configuration.md](configuration.md).
- **Keyword classification** — out of scope. The tokenizer doesn't classify
  `if` vs `while`; that's the consumer's job.
- **Escape interpretation** — out of scope. Semantics, not tokenization.
- **Whitespace as tokens** — niche. The skip-whitespace default is what 95% of
  users want.
- **Configuration object freezing** — the charset is dup'd on construct but
  not frozen internally. Could freeze it for safety; not done yet.
