# frozen_string_literal: true

require 'set'

require 'tokenzr/error'

module Tokenzr
  class ConfigurationError < Error; end

  # Describes the character sets a {Tokenizer} uses to classify characters.
  #
  # Each attribute is a string of characters belonging to that class:
  #
  # - +text+    — characters that start and continue an identifier
  # - +digits+  — characters that start and continue a number
  # - +lone+    — single-character symbols (parens, operators, punctuation)
  # - +space+   — whitespace characters that are skipped
  # - +quotes+  — characters that delimit a string
  #
  # The five sets must be pairwise disjoint; {Tokenizer.new} validates this and
  # raises {ConfigurationError} on any conflict.
  #
  # Grab a mutable copy of the defaults with {Charset.default}, tweak any field,
  # and pass it to {Tokenizer.new}:
  #
  #   charset = Tokenzr::Charset.default
  #   charset.quotes = %q{"'`}
  #   Tokenizer.new(charset:)
  #
  class Charset
    attr_accessor :text, :digits, :lone, :space, :quotes

    def initialize(text: nil, digits: nil, lone: nil, space: nil, quotes: nil)
      @text = text
      @digits = digits
      @lone = lone
      @space = space
      @quotes = quotes
    end

    # Returns a fresh, mutable copy of the default charset.
    def self.default
      new(
        text: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_',
        digits: '0123456789',
        lone: '()[]<>{}!#$%&*+,-./:;=?@\\^`|~',
        space: " \t\n\r\v\f",
        quotes: "\"'"
      )
    end

    # Returns a hash of +Set+ objects keyed by symbol, built from the current
    # charset strings. Nil charsets become empty sets.
    def to_sets
      {
        text: Set.new((text || '').chars),
        digits: Set.new((digits || '').chars),
        lone: Set.new((lone || '').chars),
        space: Set.new((space || '').chars),
        quotes: Set.new((quotes || '').chars)
      }
    end

    # Returns an array of conflict structs, one per character that appears in
    # more than one charset. Empty array when the sets are disjoint.
    def conflicts
      sets = to_sets
      tally = Hash.new { |h, k| h[k] = [] }
      sets.each do |type, set|
        set.each { |chr| tally[chr] << type }
      end
      tally.filter_map do |chr, types|
        next unless types.length > 1

        Conflict.new(chr, types)
      end
    end

    # Raised when a character appears in more than one charset.
    Conflict = Struct.new(:char, :sets)
  end
end
