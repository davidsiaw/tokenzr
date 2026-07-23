# frozen_string_literal: true

RSpec.describe Tokenzr::Tokenizer do
  describe 'charset configuration' do
    it 'uses the default charset when no charset is given' do
      tokenizer = described_class.new
      res = tokenizer.parse('abc 123 (x) "hi"')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:abc', 'number:123', 'lone:(', 'text:x', 'lone:)', 'string:"hi"']
    end

    it 'accepts a Charset object via the charset: option' do
      charset = Tokenzr::Charset.default
      charset.lone = charset.lone.delete('`')
      charset.quotes = %q{"'`}
      tokenizer = described_class.new(charset:)
      res = tokenizer.parse('`hi`')
      expect(res.length).to eq 1
      expect(res[0].type).to eq :string
      expect(res[0].content).to eq '`hi`'
    end

    it 'accepts individual charset overrides via options' do
      tokenizer = described_class.new(quotes: %q{"'`}, lone: '()[]<>{}!#$%&*+,-./:;=?@\\^|~')
      res = tokenizer.parse('`hi`')
      expect(res.length).to eq 1
      expect(res[0].type).to eq :string
      expect(res[0].content).to eq '`hi`'
    end

    it 'merges individual options over the default charset' do
      tokenizer = described_class.new(quotes: %q{"'`}, lone: '()[]<>{}!#$%&*+,-./:;=?@\\^|~')
      res = tokenizer.parse('abc')
      expect(res[0].type).to eq :text
      expect(res[0].content).to eq 'abc'
    end

    it 'freezes its own copy of the charset so later mutation has no effect' do
      charset = Tokenzr::Charset.default
      tokenizer = described_class.new(charset:)
      charset.quotes = '' # mutate after construct
      res = tokenizer.parse('"hi"')
      expect(res[0].type).to eq :string
      expect(res[0].content).to eq '"hi"'
    end

    it 'raises ConfigurationError when a char is in two sets' do
      charset = Tokenzr::Charset.new(text: 'ab1', digits: '123', lone: '()', space: ' ', quotes: '"')
      expect { described_class.new(charset:) }
        .to raise_error(Tokenzr::ConfigurationError, /conflict/i)
    end

    it 'raises ConfigurationError when options produce a conflict' do
      expect { described_class.new(text: 'ab1', digits: '123', lone: '()', space: ' ', quotes: '"') }
        .to raise_error(Tokenzr::ConfigurationError, /conflict/i)
    end

    it 'raises ConfigurationError that is a Tokenzr::Error' do
      charset = Tokenzr::Charset.new(text: 'ab1', digits: '123', lone: '()', space: ' ', quotes: '"')
      expect { described_class.new(charset:) }
        .to raise_error(Tokenzr::Error)
    end

    it 'allows customizing the text charset to add hyphen' do
      tokenizer = described_class.new(
        text: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-',
        lone: '()[]<>{}!#$%&*+,./:;=?@\\^`|~'
      )
      res = tokenizer.parse('kebab-case')
      expect(res.length).to eq 1
      expect(res[0].type).to eq :text
      expect(res[0].content).to eq 'kebab-case'
    end

    it 'allows customizing the lone charset' do
      tokenizer = described_class.new(lone: '()[]<>{}!#$%&*+,-./:;=?@\\^`|~¡')
      res = tokenizer.parse('a¡b')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:¡', 'text:b']
    end

    it 'allows customizing the space charset' do
      tokenizer = described_class.new(space: " \t\n\r\v\f\u00A0")
      res = tokenizer.parse("a\u00A0b")
      expect(res.map(&:content)).to eq ['a', 'b']
    end

    it 'allows customizing the digit charset' do
      tokenizer = described_class.new(digits: '0123456789abcdef', text: 'ghijklmnopqrstuvwxyz')
      res = tokenizer.parse('ff')
      expect(res.length).to eq 1
      expect(res[0].type).to eq :number
      expect(res[0].content).to eq 'ff'
    end
  end
end
