# frozen_string_literal: true

RSpec.describe Tokenzr::Charset do
  describe '.default' do
    it 'returns a Charset with the default text chars' do
      charset = described_class.default
      expect(charset.text).to eq 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_'
    end

    it 'returns a Charset with the default digit chars' do
      charset = described_class.default
      expect(charset.digits).to eq '0123456789'
    end

    it 'returns a Charset with the default lone chars' do
      charset = described_class.default
      expect(charset.lone).to eq '()[]<>{}!#$%&*+,-./:;=?@\\^`|~'
    end

    it 'returns a Charset with the default space chars' do
      charset = described_class.default
      expect(charset.space).to eq " \t\n\r\v\f"
    end

    it 'returns a Charset with the default quote chars' do
      charset = described_class.default
      expect(charset.quotes).to eq %q{"'}
    end

    it 'returns a fresh mutable instance each call' do
      first = described_class.default
      first.text = 'xxx'
      second = described_class.default
      expect(second.text).to eq 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_'
    end
  end

  describe '#initialize' do
    it 'accepts strings for each charset' do
      charset = described_class.new(text: 'abc', digits: '012', lone: '()', space: ' ', quotes: '"')
      expect(charset.text).to eq 'abc'
      expect(charset.digits).to eq '012'
      expect(charset.lone).to eq '()'
      expect(charset.space).to eq ' '
      expect(charset.quotes).to eq '"'
    end

    it 'defaults all charsets to nil when no arguments are given' do
      charset = described_class.new
      expect(charset.text).to be_nil
      expect(charset.digits).to be_nil
      expect(charset.lone).to be_nil
      expect(charset.space).to be_nil
      expect(charset.quotes).to be_nil
    end
  end

  describe 'writers' do
    it 'allows setting text' do
      charset = described_class.new
      charset.text = 'xyz'
      expect(charset.text).to eq 'xyz'
    end

    it 'allows setting digits' do
      charset = described_class.new
      charset.digits = '987'
      expect(charset.digits).to eq '987'
    end

    it 'allows setting lone' do
      charset = described_class.new
      charset.lone = '?!'
      expect(charset.lone).to eq '?!'
    end

    it 'allows setting space' do
      charset = described_class.new
      charset.space = " \t"
      expect(charset.space).to eq " \t"
    end

    it 'allows setting quotes' do
      charset = described_class.new
      charset.quotes = %q{"'`}
      expect(charset.quotes).to eq %q{"'`}
    end
  end

  describe '#to_sets' do
    it 'returns a hash of Sets built from the charset strings' do
      charset = described_class.new(text: 'abc', digits: '012', lone: '()', space: ' ', quotes: '"')
      sets = charset.to_sets
      expect(sets[:text]).to be_a(Set)
      expect(sets[:text].to_a.sort).to eq %w[a b c]
      expect(sets[:digits].to_a.sort).to eq %w[0 1 2]
      expect(sets[:lone].to_a.sort).to eq %w[( )]
      expect(sets[:space].to_a).to eq [' ']
      expect(sets[:quotes].to_a).to eq ['"']
    end
  end

  describe '#conflicts' do
    it 'returns an empty array when charsets are disjoint' do
      charset = described_class.new(text: 'abc', digits: '012', lone: '()', space: ' ', quotes: '"')
      expect(charset.conflicts).to eq []
    end

    it 'returns an empty array for the default charset' do
      charset = described_class.default
      expect(charset.conflicts).to eq []
    end

    it 'detects a char that is in both text and digits' do
      charset = described_class.new(text: 'ab1', digits: '123', lone: '()', space: ' ', quotes: '"')
      conflicts = charset.conflicts
      expect(conflicts).to include(have_attributes(char: '1', sets: include(:text, :digits)))
    end

    it 'detects a char that is in three sets' do
      charset = described_class.new(text: 'a', digits: 'a', lone: 'a', space: ' ', quotes: '"')
      conflicts = charset.conflicts
      expect(conflicts.length).to eq 1
      expect(conflicts[0].sets.sort).to eq %i[digits lone text]
    end

    it 'detects a char shared between space and quotes' do
      charset = described_class.new(text: 'a', digits: '0', lone: '()', space: ' ', quotes: ' "')
      conflicts = charset.conflicts
      expect(conflicts.any? { |c| c.char == ' ' && c.sets.include?(:space) && c.sets.include?(:quotes) }).to be true
    end

    it 'ignores nil charsets' do
      charset = described_class.new(text: 'a', digits: nil, lone: nil, space: nil, quotes: nil)
      expect(charset.conflicts).to eq []
    end
  end
end
