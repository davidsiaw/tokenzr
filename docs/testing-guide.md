# Testing Guide

## Running Tests

```bash
bundle exec rspec              # all tests
bundle exec rspec spec/tokenzr/tokenizer_spec.rb  # one file
bundle exec rspec -e "float"   # tests matching "float"
```

## Test Organization

```
spec/
├── spec_helper.rb                       # bundler/setup, RSpec config
├── tokenzr_spec.rb                      # version test (the gem loads)
└── tokenzr/
    ├── tokenizer_spec.rb                # core tokenization (114 tests)
    ├── charset_spec.rb                  # Charset class contract (20 tests)
    ├── charset_config_spec.rb           # Tokenizer + charset integration (12 tests)
    ├── operators_spec.rb                # multi-char operators (19 tests)
    └── customization_examples_spec.rb   # realistic end-to-end examples (11 tests)
```

177 tests total. Run `bundle exec rspec` to see the current count.

## Style Conventions

The maintainer has specified a **flat test style**. Follow these rules:

### Do
- `RSpec.describe Tokenzr::Tokenizer do` — use the class directly
- `describe '#method' do` — group by method
- `it 'does something' do` — one behavior per test
- `tokenizer = Tokenzr::Tokenizer.new` — instantiate inline in each test
- `expect(...).to eq(...)` — the `expect` syntax

### Don't
- ❌ `context 'when ...' do` — avoid context blocks
- ❌ `let(:tokenizer) { ... }` — avoid `let`
- ❌ `subject { ... }` — avoid `subject`
- ❌ `before { ... }` — avoid `before` hooks

Each test should be self-contained: create its own tokenizer, call parse,
assert. This makes tests easy to read in isolation and avoids hidden
ordering dependencies.

## Rough Edge Tests

Tests that pin surprising-but-correct behavior are marked with a comment on
the line **under** the `it`:

```ruby
it 'treats e inside a hex number as a hex digit, not an exponent' do
  # rough edge
  tokenizer = Tokenzr::Tokenizer.new
  res = tokenizer.parse('0x1e5')
  ...
end
```

Grep for them: `grep "# rough edge" spec/`. When you add a test for a
surprising behavior, mark it the same way. See [rough-edges.md](rough-edges.md)
for the full list.

## How to Add a New Tokenization Test

1. Find the right file (core behavior → `tokenizer_spec.rb`, config-related →
   `charset_config_spec.rb`, operators → `operators_spec.rb`)
2. Add an `it '...' do` block inside the appropriate `describe`
3. Instantiate a tokenizer, call `parse`, assert with `expect`
4. If the behavior is surprising, add `# rough edge` under the `it` line
5. Run `bundle exec rspec` to confirm it passes

## How to Add a New Feature

1. **Write the test first.** It should fail (red).
2. Run it to confirm it fails for the right reason (not a typo).
3. Implement the minimum code to pass (green).
4. Run the full suite to check for regressions.
5. Check `bundle exec rubocop lib/` for new offenses.
6. Update [tokenization-rules.md](tokenization-rules.md) or
   [configuration.md](configuration.md) if the behavior is user-visible.
7. If it's a rough edge, add it to [rough-edges.md](rough-edges.md) and mark
   the test.

## RuboCop

```bash
bundle exec rubocop lib/    # the gem code
bundle exec rubocop spec/   # the tests (will show style offenses — see below)
```

The lib code should stay rubocop-clean except for known metric offenses
(`Metrics/ClassLength` on `Tokenizer`, `Metrics/ParameterLists` on the
`Charset` constructor — both are inherent to the design).

The spec files will show `RSpec/DescribedClass`, `RSpec/MultipleExpectations`,
and `RSpec/ExampleLength` offenses because the flat style conflicts with
those cops. **Do not "fix" these by introducing `let`/`subject`/`context`** —
the maintainer has explicitly chosen the flat style. If the offense count
becomes annoying, silence those cops in `.rubocop.yml` instead.

## CI

GitHub Actions workflows (in `.github/workflows/`):
- `test.yml` — runs rspec on Ruby 3.4 and 4.0, ubuntu and macos
- `lint.yml` — runs rubocop via reviewdog on PRs
- `docs.yml` — builds YARD docs and deploys to GitHub Pages on master push
