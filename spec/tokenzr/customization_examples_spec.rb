# frozen_string_literal: true

# These specs illustrate realistic customizations a user might apply to the
# tokenizer. Each example grabs the default charset, modifies the relevant
# fields (taking care to remove chars from their original set when moving them
# to another), and verifies the resulting behavior end-to-end.

RSpec.describe Tokenzr::Tokenizer, 'customization examples' do
  it 'tokenizes kebab-case identifiers by moving hyphen from lone to text' do
    charset = Tokenzr::Charset.default
    charset.lone = charset.lone.delete('-')
    charset.text = charset.text + '-'
    tokenizer = described_class.new(charset:)

    res = tokenizer.parse('my-kebab-variable = 42')

    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq [
      'text:my-kebab-variable', 'lone:=', 'number:42'
    ]
  end

  it 'tokenizes backtick-quoted strings by moving backtick from lone to quotes' do
    charset = Tokenzr::Charset.default
    charset.lone = charset.lone.delete('`')
    charset.quotes = charset.quotes + '`'
    tokenizer = described_class.new(charset:)

    res = tokenizer.parse('let x = `hello world`')

    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq [
      'text:let', 'text:x', 'lone:=', 'string:`hello world`'
    ]
  end

  it 'tokenizes Ruby-style method names by moving ? and ! from lone to text' do
    charset = Tokenzr::Charset.default
    charset.lone = charset.lone.delete('!').delete('?')
    charset.text = charset.text + '!?'
    tokenizer = described_class.new(charset:)

    res = tokenizer.parse('if empty? then done! end')

    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq [
      'text:if', 'text:empty?', 'text:then', 'text:done!', 'text:end'
    ]
  end

  it 'tokenizes hex-only digit sets for a hex-language' do
    charset = Tokenzr::Charset.default
    charset.digits = '0123456789abcdef'
    charset.text = charset.text.delete('abcdef') # avoid conflict
    tokenizer = described_class.new(charset:)

    res = tokenizer.parse('ff + 1a')

    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq [
      'number:ff', 'lone:+', 'number:1a'
    ]
  end

  it 'tokenizes with extra whitespace characters (non-breaking space)' do
    charset = Tokenzr::Charset.default
    charset.space = charset.space + "\u00A0"
    tokenizer = described_class.new(charset:)

    res = tokenizer.parse("a\u00A0b")

    expect(res.map(&:content)).to eq ['a', 'b']
  end

  it 'tokenizes with a stripped-down lone set (only parens)' do
    charset = Tokenzr::Charset.default
    # move all the operator/punctuation chars into... nowhere (remove them).
    # They will then raise UnknownCharError if encountered.
    charset.lone = '()'
    tokenizer = described_class.new(charset:)

    res = tokenizer.parse('foo(bar)')

    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq [
      'text:foo', 'lone:(', 'text:bar', 'lone:)'
    ]

    expect { tokenizer.parse('a+b') }.to raise_error(Tokenzr::UnknownCharError)
  end

  it 'builds a tokenizer from individual options without a Charset object' do
    tokenizer = described_class.new(
      text: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-',
      lone: '()[]<>{}!#$%&*+,./:;=?@\\^`|~'
    )

    res = tokenizer.parse('snake_case and kebab-case')

    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq [
      'text:snake_case', 'text:and', 'text:kebab-case'
    ]
  end

  it 'raises a clear ConfigurationError naming the conflicting char and sets' do
    charset = Tokenzr::Charset.default
    charset.quotes = charset.quotes + 'a' # 'a' is already in text

    expect { described_class.new(charset:) }
      .to raise_error(Tokenzr::ConfigurationError, /"a" in quotes, text/)
  end

  it 'does not mutate the charset passed to it' do
    charset = Tokenzr::Charset.default
    original_quotes = charset.quotes
    described_class.new(charset:)
    charset.quotes = 'XX' # mutate after construct; tokenizer already built

    expect(charset.quotes).to eq 'XX' # the user's object is theirs to mutate
    expect(original_quotes).to eq "\"'" # sanity: we saved the original value
  end

  it 'tokenizes hiragana identifiers by adding them to the text charset' do
    charset = Tokenzr::Charset.default
    charset.text = charset.text + 'ぁあぃいぅうぇえぉおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん'
    tokenizer = described_class.new(charset:)

    res = tokenizer.parse('hello こんにちは world')

    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq [
      'text:hello', 'text:こんにちは', 'text:world'
    ]
  end

  it 'tokenizes CSV by putting all chars in text and keeping only comma as lone' do
    text_chars = (32..126).map(&:chr).join.delete('"').delete(',')
    charset = Tokenzr::Charset.new(
      text: text_chars,
      digits: '',
      lone: ',',
      space: '',
      quotes: '"'
    )
    tokenizer = described_class.new(charset:)

    res = tokenizer.parse('"hello, world",foo,123')

    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq [
      'string:"hello, world"', 'lone:,', 'text:foo', 'lone:,', 'text:123'
    ]
  end
end
