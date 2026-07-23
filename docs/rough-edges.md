# Rough Edges

These are surprising-but-correct behaviors that are pinned by tests (grep
`# rough edge` in `spec/tokenzr/tokenizer_spec.rb` and
`spec/tokenzr/operators_spec.rb`). They're not bugs — they're deliberate
design choices or natural consequences of the rules. Document them if you ever
write user-facing docs.

## Number Rough Edges

### `0x1e5` — `e` is a hex digit, not an exponent

```
0x1e5 → :number "0x1e5"  (one hex number)
```

Inside a hex number, `e` is a valid hex digit. There's no exponent in hex.
If you expected `0x1` + `e5`, that's not what happens — the hex reader
consumes all hex digits greedily.

### `1.e5` — no float, because no fractional digit

```
1.e5 → :number "1", :lone ".", :text "e5"
```

The fraction rule requires a digit after the `.`. Since `e` follows the dot,
the `.` falls out as a lone token, and `e5` becomes a text identifier. If you
wanted `1.0e5`, write it explicitly.

### `00x5` — hex prefix not recognized after leading zeros

```
00x5 → :number "00", :text "x5"
```

Hex is only recognized after a **single** `0`. `00` is the integer part, so
`0x` isn't seen as a hex prefix. Write `0x05` if you mean hex.

### `1e-` and `1e+` — sign with no digits falls back

```
1e- → :number "1", :text "e", :lone "-"
1e+ → :number "1", :text "e", :lone "+"
```

The exponent reader consumes `e` and the sign, but if no digit follows, it
emits the number, then `e` as text and the sign as a lone token. The sign is
returned as `:lone` (it's a symbol), not `:text`.

### `1e10e5` — second `e` is not an exponent

```
1e10e5 → :number "1e10", :text "e5"
```

After `1e10` is consumed as a number, the second `e` starts a text token
(`e5` is a valid identifier). Numbers only have one exponent.

### `1..5` — consecutive dots

```
1..5 → :number "1", :lone ".", :lone ".", :number "5"
```

The first `.` after `1` has no digit after it (the next char is `.`), so it's
a lone token. Same for the second. This is how you'd tokenize a range
operator if you added `..` to `operators`.

### `1e5.5` — no second fraction

```
1e5.5 → :number "1e5", :lone ".", :number "5"
```

A number has at most one fraction and one exponent. After `1e5`, the `.` is a
lone token and `5` is a new number.

### `0x1Fhello` — hex stops at non-hex char

```
0x1Fhello → :number "0x1F", :text "hello"
```

`h` is not a hex digit, so the hex reader stops. `hello` continues as a text
token (letters are text chars).

## String Rough Edges

### `"\\"` (escaped backslash + closing quote) — works

A 4-char input `"`, `\`, `\`, `"` is a valid string containing one literal
backslash. The first `\` escapes the second `\` (literal backslash), then the
`"` closes the string.

### `"\"` (backslash escapes closing quote) — unterminated

A 3-char input `"`, `\`, `"` is **unterminated** — the `\` escapes the `"`, so
there's no closing quote. Raises `UnterminatedStringError`.

### Backslash is dual-purpose

Outside a string, `\` is a `:lone` token. Inside a string, `\` is the escape
character. These are separate code paths and don't conflict. If you don't want
backslash as a lone token, remove it from the `lone` charset.

## Whitespace Rough Edges

### Bare `\r` doesn't reset column

```
a\rb → :text "a" (1:1), :text "b" (1:3)  ← column 3, not 1
```

Only `\n` resets the column. CRLF (`\r\n`) works because `\r` is skipped and
`\n` resets. Bare `\r` (classic Mac) files will have wrong column numbers.

## Operator Rough Edges

### `==D` as an operator would eat text chars

If someone defines `operators: ['==D']`, the `D` would be swallowed from
`A==D` into the operator token. This is why operator validation requires
**all** chars to be in the `lone` charset — it raises `ConfigurationError` at
construct time instead of silently producing wrong tokens.

### `===` with `operators: ['==']` — not `==` + `=`

```
=== → :lone "==", :lone "="
```

Greedy left-to-right: `==` matches first, then `=` is alone. Not `=` + `==`.
This is standard maximal-munch behavior.
