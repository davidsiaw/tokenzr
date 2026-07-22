# frozen_string_literal: true

RSpec.describe Tokenzr::Tokenizer do
  describe '#parse' do
    it 'tokenizes a single text token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abcd')
      expect(res.length).to eq 1
      expect(res[0].content).to eq 'abcd'
      expect(res[0].type).to eq :text
    end

    it 'tokenizes parens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abcd()')
      expect(res.length).to eq 3
      expect(res[0].content).to eq 'abcd'
      expect(res[1].content).to eq '('
      expect(res[2].content).to eq ')'
    end

    it 'tokenizes parens 2' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abcd ()')
      expect(res.length).to eq 3
      expect(res[0].content).to eq 'abcd'
      expect(res[1].content).to eq '('
      expect(res[2].content).to eq ')'
    end

    it 'tokenizes parens 3' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abcd (a)')
      expect(res.length).to eq 4
      expect(res[0].content).to eq 'abcd'
      expect(res[1].content).to eq '('
      expect(res[2].content).to eq 'a'
      expect(res[3].content).to eq ')'
    end

    it 'keeps multi-char text after a lone token as one token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('(abc)')
      expect(res.length).to eq 3
      expect(res[0].content).to eq '('
      expect(res[1].content).to eq 'abc'
      expect(res[2].content).to eq ')'
    end

    it 'returns an empty array for an empty string' do
      tokenizer = Tokenzr::Tokenizer.new
      expect(tokenizer.parse('')).to eq []
    end

    it 'returns an empty array for only spaces' do
      tokenizer = Tokenzr::Tokenizer.new
      expect(tokenizer.parse('   ')).to eq []
    end

    it 'returns an empty array for mixed whitespace' do
      tokenizer = Tokenzr::Tokenizer.new
      expect(tokenizer.parse(" \t\n\r")).to eq []
    end

    it 'collapses consecutive spaces into no space tokens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('a  b')
      expect(res.length).to eq 2
      expect(res[0].content).to eq 'a'
      expect(res[1].content).to eq 'b'
    end

    it 'handles leading and trailing spaces' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('  abcd  ')
      expect(res.length).to eq 1
      expect(res[0].content).to eq 'abcd'
    end

    it 'tokenizes consecutive lone tokens separately' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('()[]')
      expect(res.length).to eq 4
      expect(res.map(&:content)).to eq %w[( ) [ ]]
    end

    it 'tokenizes a single lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('(')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '('
      expect(res[0].type).to eq :lone
    end

    it 'sets the correct type on text tokens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('hello')
      expect(res[0].type).to eq :text
    end

    it 'sets the correct type on lone tokens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('{')
      expect(res[0].type).to eq :lone
    end

    it 'tokenizes an exclamation mark as a lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('hello!')
      expect(res.map(&:content)).to eq ['hello', '!']
      expect(res[1].type).to eq :lone
    end

    it 'tokenizes an at sign as a lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('@')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '@'
      expect(res[0].type).to eq :lone
    end

    it 'tokenizes a question mark as a lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('?')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '?'
      expect(res[0].type).to eq :lone
    end

    it 'tokenizes a standalone number as a :number token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('123')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '123'
      expect(res[0].type).to eq :number
    end

    it 'allows digits inside an identifier started by text' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abc123')
      expect(res.length).to eq 1
      expect(res[0].content).to eq 'abc123'
      expect(res[0].type).to eq :text
    end

    it 'splits a number followed by text into separate tokens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('123abc')
      expect(res.length).to eq 2
      expect(res[0].content).to eq '123'
      expect(res[0].type).to eq :number
      expect(res[1].content).to eq 'abc'
      expect(res[1].type).to eq :text
    end

    it 'tokenizes a double-quoted string as one :string token including quotes' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('"hello world"')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '"hello world"'
      expect(res[0].type).to eq :string
    end

    it 'tokenizes a single-quoted string as one :string token including quotes' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("'hello world'")
      expect(res.length).to eq 1
      expect(res[0].content).to eq "'hello world'"
      expect(res[0].type).to eq :string
    end

    it 'preserves spaces inside a quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('a  "b  c"  d')
      expect(res.map(&:content)).to eq ['a', '"b  c"', 'd']
    end

    it 'handles an escaped double quote inside a double-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('"a\"b"')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '"a\"b"'
      expect(res[0].type).to eq :string
    end

    it 'handles an escaped single quote inside a single-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("'a\\'b'")
      expect(res.length).to eq 1
      expect(res[0].content).to eq "'a\\'b'"
      expect(res[0].type).to eq :string
    end

    it 'treats a single quote as literal inside a double-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("\"it's\"")
      expect(res.length).to eq 1
      expect(res[0].content).to eq "\"it's\""
    end

    it 'treats a double quote as literal inside a single-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("'say \"hi\"'")
      expect(res.length).to eq 1
      expect(res[0].content).to eq "'say \"hi\"'"
    end

    it 'treats a backslash as literal when not before the matching quote' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("'a\\b'")
      expect(res.length).to eq 1
      expect(res[0].content).to eq "'a\\b'"
    end

    it 'raises UnterminatedStringError for an unclosed double-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      expect { tokenizer.parse('"hello') }
        .to raise_error(Tokenzr::UnterminatedStringError)
    end

    it 'raises UnterminatedStringError for an unclosed single-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      expect { tokenizer.parse("'hello") }
        .to raise_error(Tokenzr::UnterminatedStringError)
    end

    it 'raises UnterminatedStringError that is a Tokenzr::Error' do
      tokenizer = Tokenzr::Tokenizer.new
      expect { tokenizer.parse('"hello') }
        .to raise_error(Tokenzr::Error)
    end

    it 'tokenizes a mix of identifiers, numbers, strings and symbols' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('foo(123 "bar baz")')
      expect(res.map(&:content)).to eq ['foo', '(', '123', '"bar baz"', ')']
    end

    it 'tokenizes an empty double-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('""')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '""'
      expect(res[0].type).to eq :string
    end

    it 'tokenizes an empty single-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("''")
      expect(res.length).to eq 1
      expect(res[0].content).to eq "''"
      expect(res[0].type).to eq :string
    end

    it 'flushes a text token when a string starts immediately after' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abc"def"')
      expect(res.map(&:content)).to eq ['abc', '"def"']
      expect(res[0].type).to eq :text
      expect(res[1].type).to eq :string
    end

    it 'flushes a number token when a string starts immediately after' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('123"abc"')
      expect(res.map(&:content)).to eq ['123', '"abc"']
      expect(res[0].type).to eq :number
      expect(res[1].type).to eq :string
    end

    it 'flushes a lone token when a string starts immediately after' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('("abc")')
      expect(res.map(&:content)).to eq ['(', '"abc"', ')']
    end

    it 'tokenizes a string immediately after a string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('"abc""def"')
      expect(res.map(&:content)).to eq ['"abc"', '"def"']
    end

    it 'tokenizes a float as a single number token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1.5')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '1.5'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes a float with no fractional digits as a number then a lone dot' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1.')
      expect(res.map(&:content)).to eq ['1', '.']
      expect(res[0].type).to eq :number
      expect(res[1].type).to eq :lone
    end

    it 'tokenizes a leading-dot float as a lone dot then a number' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('.5')
      expect(res.map(&:content)).to eq ['.', '5']
      expect(res[1].type).to eq :number
    end

    it 'tokenizes a hex number as a single number token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0x1F')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '0x1F'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes an uppercase hex number as a single number token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0X1F')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '0X1F'
      expect(res[0].type).to eq :number
    end

    it 'falls back to number and text when 0x is not followed by a hex digit' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0xG')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:0', 'text:x', 'text:G']
    end

    it 'falls back to number and text when 0x has no hex digits' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0x')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:0', 'text:x']
    end

    it 'tokenizes a scientific notation number as a single number token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e10')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '1e10'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes a scientific notation number with uppercase E' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1E10')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '1E10'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes a scientific notation number with a plus sign' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e+10')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '1e+10'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes a scientific notation number with a minus sign' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e-10')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '1e-10'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes a float with a scientific exponent' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1.5e3')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '1.5e3'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes a float with a negative scientific exponent' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1.5e-3')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '1.5e-3'
      expect(res[0].type).to eq :number
    end

    it 'falls back to number and text when e is not followed by an exponent' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:1', 'text:e']
    end

    it 'falls back to number and text when e is followed by a second exponent' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e10e5')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:1e10', 'text:e5']
    end

    it 'tokenizes a hex number followed by a dot and decimal as separate tokens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0x1F.5')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:0x1F', 'lone:.', 'number:5']
    end

    it 'tokenizes a number followed by an identifier as separate tokens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e10abc')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:1e10', 'text:abc']
    end

    it 'tokenizes a minus sign as a lone token before a number' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('-1')
      expect(res.map(&:content)).to eq ['-', '1']
      expect(res[0].type).to eq :lone
      expect(res[1].type).to eq :number
    end

    it 'raises NoMethodError for nil input' do
      tokenizer = Tokenzr::Tokenizer.new
      expect { tokenizer.parse(nil) }.to raise_error(NoMethodError)
    end

    it 'raises UnterminatedStringError for a string ending on a dangling backslash' do
      tokenizer = Tokenzr::Tokenizer.new
      expect { tokenizer.parse('"abc\\') }
        .to raise_error(Tokenzr::UnterminatedStringError)
    end

    it 'tokenizes a string containing a lone char literally' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('"a(b)c"')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '"a(b)c"'
      expect(res[0].type).to eq :string
    end

    it 'raises UnterminatedStringError when a backslash escapes the final quote' do
      tokenizer = Tokenzr::Tokenizer.new
      # input is the 3 chars: " \ "  (backslash escapes the closing quote)
      expect { tokenizer.parse("\"\\\"") }
        .to raise_error(Tokenzr::UnterminatedStringError)
    end

    it 'tokenizes a string containing a literal backslash followed by a real closing quote' do
      tokenizer = Tokenzr::Tokenizer.new
      # input is the 4 chars: " \ \ "  (escaped backslash, then real closing quote)
      res = tokenizer.parse("\"\\\\\"")
      expect(res.length).to eq 1
      expect(res[0].content).to eq "\"\\\\\""
      expect(res[0].type).to eq :string
    end

    it 'tokenizes an identifier that is only underscores' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('___')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '___'
      expect(res[0].type).to eq :text
    end

    it 'tokenizes a single underscore' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('_')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '_'
      expect(res[0].type).to eq :text
    end

    it 'tokenizes a single digit' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('5')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '5'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes a lone token followed immediately by a number' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('(123)')
      expect(res.map(&:content)).to eq ['(', '123', ')']
      expect(res[1].type).to eq :number
    end

    it 'collapses a mix of spaces, tabs and newlines between tokens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("a \t\n b")
      expect(res.map(&:content)).to eq ['a', 'b']
    end

    it 'tokenizes a comma between identifiers as a lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('a,b')
      expect(res.map(&:content)).to eq ['a', ',', 'b']
      expect(res[1].type).to eq :lone
    end

    it 'tokenizes a semicolon between identifiers as a lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('a;b')
      expect(res.map(&:content)).to eq ['a', ';', 'b']
      expect(res[1].type).to eq :lone
    end

    it 'tokenizes a hash between identifiers as a lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('a#b')
      expect(res.map(&:content)).to eq ['a', '#', 'b']
      expect(res[1].type).to eq :lone
    end

    it 'tokenizes all remaining printable ASCII symbols as lone tokens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('!#$%&*+,-./:;=?@\\^`|~')
      expect(res.all? { |t| t.type == :lone }).to be true
      expect(res.map(&:content)).to eq '!#$%&*+,-./:;=?@\\^`|~'.chars
    end

    it 'tokenizes arithmetic operators as lone tokens' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('a+b*c/d')
      expect(res.map(&:content)).to eq ['a', '+', 'b', '*', 'c', '/', 'd']
      expect(res.select { |t| t.type == :lone }.map(&:content)).to eq %w[+ * /]
    end

    it 'tokenizes an equals sign as a lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('x=1')
      expect(res.map(&:content)).to eq ['x', '=', '1']
      expect(res[1].type).to eq :lone
    end

    it 'tokenizes a backslash outside a string as a lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('a\\b')
      expect(res.map(&:content)).to eq ['a', '\\', 'b']
      expect(res[1].type).to eq :lone
    end

    it 'tokenizes consecutive identical lone tokens separately' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('((')
      expect(res.length).to eq 2
      expect(res[0].content).to eq '('
      expect(res[1].content).to eq '('
      expect(res.all? { |t| t.type == :lone }).to be true
    end

    it 'tokenizes consecutive identical operator tokens separately' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('++')
      expect(res.length).to eq 2
      expect(res[0].content).to eq '+'
      expect(res[1].content).to eq '+'
      expect(res.all? { |t| t.type == :lone }).to be true
    end

    it 'tokenizes a number with leading zeros' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('007')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '007'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes a number that is only zeros' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('00')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '00'
      expect(res[0].type).to eq :number
    end

    it 'flushes a string token when text starts immediately after' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('"abc"def')
      expect(res.map(&:content)).to eq ['"abc"', 'def']
      expect(res[0].type).to eq :string
      expect(res[1].type).to eq :text
    end

    it 'merges text and trailing digits after an initial number' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('123abc456')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:123', 'text:abc456']
    end

    it 'preserves a real newline inside a double-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("a \"b\nc\" d")
      expect(res.map(&:content)).to eq ['a', "\"b\nc\"", 'd']
    end

    it 'preserves a real tab inside a double-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("a \"b\tc\" d")
      expect(res.map(&:content)).to eq ['a', "\"b\tc\"", 'd']
    end

    it 'preserves unicode characters inside a double-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('"caf\u00e9"')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '"caf\u00e9"'
      expect(res[0].type).to eq :string
    end

    it 'handles multiple escaped quotes inside a double-quoted string' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('"a\"b\"c"')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '"a\"b\"c"'
      expect(res[0].type).to eq :string
    end

    it 'tokenizes an identifier with embedded underscores and digits' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abc_123')
      expect(res.length).to eq 1
      expect(res[0].content).to eq 'abc_123'
      expect(res[0].type).to eq :text
    end

    it 'raises UnknownCharError for a non-ASCII character' do
      tokenizer = Tokenzr::Tokenizer.new
      expect { tokenizer.parse('a€b') }
        .to raise_error(Tokenzr::UnknownCharError, /Unknown character/)
    end

    it 'raises UnknownCharError that is a Tokenzr::Error' do
      tokenizer = Tokenzr::Tokenizer.new
      expect { tokenizer.parse('a€b') }
        .to raise_error(Tokenzr::Error)
    end

    it 'treats e inside a hex number as a hex digit, not an exponent' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0x1e5')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '0x1e5'
      expect(res[0].type).to eq :number
    end

    it 'does not treat 1.e5 as a float with exponent (no fractional digit)' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1.e5')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:1', 'lone:.', 'text:e5']
    end

    it 'does not recognize hex prefix after a leading zero' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('00x5')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:00', 'text:x5']
    end

    it 'falls back to number, text and lone when e is followed by a minus with no digits' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e-')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:1', 'text:e', 'lone:-']
    end

    it 'falls back to number, text and lone when e is followed by a plus with no digits' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e+')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:1', 'text:e', 'lone:+']
    end

    it 'tokenizes consecutive dots as separate lone tokens' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1..5')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:1', 'lone:.', 'lone:.', 'number:5']
    end

    it 'tokenizes a float exponent with a trailing dot as separate tokens' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e5.5')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:1e5', 'lone:.', 'number:5']
    end

    it 'stops a hex number at the first non-hex character' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0x1Fhello')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:0x1F', 'text:hello']
    end

    it 'stops a hex number at a non-hex letter and continues as text' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0xabcdefg')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:0xabcdef', 'text:g']
    end

    it 'tokenizes a hex zero as a single number token' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0x0')
      expect(res.length).to eq 1
      expect(res[0].content).to eq '0x0'
      expect(res[0].type).to eq :number
    end

    it 'tokenizes 0x with a following dot as number, text, lone, number' do
      # rough edge
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0x.5')
      expect(res.map { |t| "#{t.type}:#{t.content}" }).to eq ['number:0', 'text:x', 'lone:.', 'number:5']
    end

    it 'records line 1 column 1 for the first token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abc')
      expect(res[0].line).to eq 1
      expect(res[0].column).to eq 1
    end

    it 'records the column of the second token on the same line' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abc 123')
      expect(res[0].line).to eq 1
      expect(res[0].column).to eq 1
      expect(res[1].line).to eq 1
      expect(res[1].column).to eq 5
    end

    it 'records the line and column of a token on the second line' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("abc\n  def")
      expect(res[1].line).to eq 2
      expect(res[1].column).to eq 3
    end

    it 'records the position of a lone token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('abc()')
      expect(res[1].line).to eq 1
      expect(res[1].column).to eq 4
      expect(res[2].line).to eq 1
      expect(res[2].column).to eq 5
    end

    it 'records the start position of a string token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('  "hi"')
      expect(res[0].line).to eq 1
      expect(res[0].column).to eq 3
    end

    it 'records the start position of a string spanning multiple lines' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("x \"a\nb\" y")
      expect(res[1].line).to eq 1
      expect(res[1].column).to eq 3
      expect(res[2].line).to eq 2
      expect(res[2].column).to eq 4
    end

    it 'records the start position of a number token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('  123')
      expect(res[0].line).to eq 1
      expect(res[0].column).to eq 3
    end

    it 'records the start position of a float token' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1.5')
      expect(res[0].line).to eq 1
      expect(res[0].column).to eq 1
    end

    it 'records the position of fallback tokens from a failed hex prefix' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('0x')
      expect(res[0].line).to eq 1
      expect(res[0].column).to eq 1
      expect(res[1].line).to eq 1
      expect(res[1].column).to eq 2
    end

    it 'records the position of fallback tokens from a failed fraction' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1.')
      expect(res[0].line).to eq 1
      expect(res[0].column).to eq 1
      expect(res[1].line).to eq 1
      expect(res[1].column).to eq 2
    end

    it 'records the position of fallback tokens from a failed exponent' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse('1e-')
      expect(res[0].line).to eq 1
      expect(res[0].column).to eq 1
      expect(res[1].line).to eq 1
      expect(res[1].column).to eq 2
      expect(res[2].line).to eq 1
      expect(res[2].column).to eq 3
    end

    it 'resets column to 1 after each newline' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("a\nb\nc")
      expect(res.map { |t| [t.line, t.column] }).to eq [[1, 1], [2, 1], [3, 1]]
    end

    it 'counts each character as one column including tabs' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("a\tb")
      expect(res[0].column).to eq 1
      expect(res[1].column).to eq 3
    end

    it 'treats a vertical tab as whitespace' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("a\vb")
      expect(res.map(&:content)).to eq ['a', 'b']
    end

    it 'treats a form feed as whitespace' do
      tokenizer = Tokenzr::Tokenizer.new
      res = tokenizer.parse("a\fb")
      expect(res.map(&:content)).to eq ['a', 'b']
    end

    it 'treats a vertical-tab-only input as empty' do
      tokenizer = Tokenzr::Tokenizer.new
      expect(tokenizer.parse("\v")).to eq []
    end

    it 'treats a form-feed-only input as empty' do
      tokenizer = Tokenzr::Tokenizer.new
      expect(tokenizer.parse("\f")).to eq []
    end
  end
end
