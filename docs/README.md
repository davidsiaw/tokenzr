# Tokenzr — Maintainer Documentation

This directory contains documentation for maintainers and contributors of the
tokenzr gem. It covers the architecture, design decisions, tokenization rules,
configuration, and known rough edges.

## Contents

**For users:**
- [**Usage Guide**](usage-guide.md) — how to use the gem, common patterns,
  error handling, and when to customize
- [**Examples**](examples.md) — ready-to-use snippets for common customizations

**For maintainers:**
- [**Architecture**](architecture.md) — file layout, require graph, how the
  pieces fit together
- [**Tokenization Rules**](tokenization-rules.md) — the exact rules for each
  token type, precedence, and position tracking
- [**Configuration**](configuration.md) — the `Charset` object, constructor
  options, conflict validation, and operator validation
- [**Design Decisions**](design-decisions.md) — why things are the way they are,
  including deferred features and things we deliberately left out
- [**Rough Edges**](rough-edges.md) — surprising-but-correct behaviors pinned by
  tests (grep `# rough edge` in the specs)
- [**Testing Guide**](testing-guide.md) — how the tests are organized, the flat
  style convention, and how to add new tests

## Quick Orientation

```
lib/
├── tokenzr.rb              # loader — requires the others
└── tokenzr/
    ├── version.rb          # VERSION constant
    ├── error.rb            # Error, UnknownCharError, UnterminatedStringError
    ├── charset.rb          # Charset (configurable charsets) + ConfigurationError
    ├── token.rb            # Token (immutable value object)
    └── tokenizer.rb        # Tokenizer (the parser)
```

Entry point: `Tokenzr::Tokenizer.new.parse(string)` → returns an array of
`Tokenzr::Token` objects with `content`, `type`, `line`, `column`.

See [architecture.md](architecture.md) for the require graph and data flow.
