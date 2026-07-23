# frozen_string_literal: true

RSpec.describe Tokenzr::Tokenizer, 'multi-char operators' do
  it 'tokenizes a double-equals operator as one lone token' do
    tokenizer = described_class.new(operators: ['=='])
    res = tokenizer.parse('a==b')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:==', 'text:b']
  end

  it 'tokenizes several common operators' do
    tokenizer = described_class.new(operators: ['==', '!=', '<=', '>=', '=>'])
    res = tokenizer.parse('a==b c!=d e<=f g>=h i=>j')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq [
      'text:a', 'lone:==', 'text:b',
      'text:c', 'lone:!=', 'text:d',
      'text:e', 'lone:<=', 'text:f',
      'text:g', 'lone:>=', 'text:h',
      'text:i', 'lone:=>', 'text:j'
    ]
  end

  it 'falls back to a single lone token when the operator does not match' do
    tokenizer = described_class.new(operators: ['=='])
    res = tokenizer.parse('a=b')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:=', 'text:b']
  end

  it 'matches the longest operator first when prefixes overlap' do
    tokenizer = described_class.new(operators: ['==', '==='])
    res = tokenizer.parse('a===b')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:===', 'text:b']
  end

  it 'matches the shorter operator when the longer one does not fit' do
    tokenizer = described_class.new(operators: ['==', '==='])
    res = tokenizer.parse('a==b')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:==', 'text:b']
  end

  it 'tokenizes arrow and scope operators' do
    tokenizer = described_class.new(operators: ['->', '::'])
    res = tokenizer.parse('a->b::c')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:->', 'text:b', 'lone:::', 'text:c']
  end

  it 'tokenizes logical operators' do
    tokenizer = described_class.new(operators: ['&&', '||'])
    res = tokenizer.parse('a&&b||c')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:&&', 'text:b', 'lone:||', 'text:c']
  end

  it 'records the start position of a multi-char operator' do
    tokenizer = described_class.new(operators: ['=='])
    res = tokenizer.parse('a==b')
    expect(res[1].line).to eq 1
    expect(res[1].column).to eq 2
  end

  it 'records the position of the token after a multi-char operator' do
    tokenizer = described_class.new(operators: ['=='])
    res = tokenizer.parse('a==b')
    expect(res[2].line).to eq 1
    expect(res[2].column).to eq 4
  end

  it 'does not treat an operator-looking sequence as an operator inside a string' do
    tokenizer = described_class.new(operators: ['=='])
    res = tokenizer.parse('"a==b"')
    expect(res.length).to eq 1
    expect(res[0].type).to eq :string
    expect(res[0].content).to eq '"a==b"'
  end

  it 'has no operators by default' do
    tokenizer = described_class.new
    res = tokenizer.parse('a==b')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:=', 'lone:=', 'text:b']
  end

  it 'treats an empty operators array the same as no operators' do
    tokenizer = described_class.new(operators: [])
    res = tokenizer.parse('a==b')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:=', 'lone:=', 'text:b']
  end

  it 'handles an operator at end of input' do
    tokenizer = described_class.new(operators: ['=='])
    res = tokenizer.parse('a==')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['text:a', 'lone:==']
  end

  it 'handles a three-char operator with position tracking across the token' do
    tokenizer = described_class.new(operators: ['<=>'])
    res = tokenizer.parse('a<=>b')
    expect(res[1].line).to eq 1
    expect(res[1].column).to eq 2
    expect(res[2].line).to eq 1
    expect(res[2].column).to eq 5
  end

  it 'handles consecutive operators' do
    tokenizer = described_class.new(operators: ['==', '!='])
    res = tokenizer.parse('==!=')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['lone:==', 'lone:!=']
  end

  it 'handles an operator after a number' do
    tokenizer = described_class.new(operators: ['=='])
    res = tokenizer.parse('1==2')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:1', 'lone:==', 'number:2']
  end

  it 'raises ConfigurationError when an operator contains a char not in the lone charset' do
    charset = Tokenzr::Charset.default
    charset.operators = ['ab'] # 'a' and 'b' are in text, not lone
    expect { described_class.new(charset:) }
      .to raise_error(Tokenzr::ConfigurationError, /Operator.*ab.*not in.*lone/i)
  end

  it 'raises ConfigurationError when an operator has a text char in a non-first position' do # rough edge
    charset = Tokenzr::Charset.default
    charset.operators = ['==D'] # 'D' is a text char
    expect { described_class.new(charset:) }
      .to raise_error(Tokenzr::ConfigurationError, /Operator.*==D.*not in.*lone/i)
  end

  it 'accepts operators whose chars are all in the lone charset' do
    tokenizer = described_class.new(operators: ['=='])
    res = tokenizer.parse('==')
    expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['lone:==']
  end
end
