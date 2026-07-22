# frozen_string_literal: true

require 'set'
require 'tokenzr/version'

module Tokenzr
  class Error < StandardError; end
  class UnknownCharError < Error; end
  class UnterminatedStringError < Error; end

  class Token
    attr_reader :content, :type, :line, :column

    def initialize(content = nil, type = nil, line = nil, column = nil)
      @content = content
      @type = type
      @line = line
      @column = column
    end
  end

  class Tokenizer
    def text_chars
      @text_chars ||= Set.new('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_'.chars)
    end

    def digit_chars
      @digit_chars ||= Set.new('0123456789'.chars)
    end

    def lone_chars
      @lone_chars ||= Set.new('()[]<>{}!#$%&*+,-./:;=?@\\^`|~'.chars)
    end

    def space_chars
      @space_chars ||= Set.new(" \t\n\r\v\f".chars)
    end

    def string_quotes
      @string_quotes ||= Set.new(%q{"'}.chars)
    end

    def parse(content)
      results = []
      current_token = nil
      enum = content.each_char
      @line = 1
      @column = 1
      @cur_line = 1
      @cur_col = 1

      while (chr = next_char(enum))
        start_line = @cur_line
        start_col = @cur_col

        if string_quotes.include?(chr)
          results << current_token unless current_token.nil?
          current_token = nil
          results << read_string(enum, chr, start_line, start_col)
          next
        end

        if space_chars.include?(chr)
          results << current_token unless current_token.nil?
          current_token = nil
          next
        end

        if digit_chars.include?(chr)
          if !current_token.nil? && current_token.type == :text
            # digits continue an identifier started by text/underscore
            current_token = Token.new(current_token.content + chr, :text, current_token.line, current_token.column)
            next
          end

          results << current_token unless current_token.nil?
          current_token = nil
          result = read_number(enum, chr, start_line, start_col)
          if result.is_a?(Array)
            results.concat(result)
          else
            results << result
          end
          next
        end

        if text_chars.include?(chr)
          if !current_token.nil? && current_token.type == :text
            current_token = Token.new(current_token.content + chr, :text, current_token.line, current_token.column)
          else
            results << current_token unless current_token.nil?
            current_token = Token.new(chr, :text, start_line, start_col)
          end
          next
        end

        if lone_chars.include?(chr)
          results << current_token unless current_token.nil?
          current_token = nil
          results << Token.new(chr, :lone, start_line, start_col)
          next
        end

        raise UnknownCharError, "Unknown character: #{chr.inspect}"
      end

      results << current_token unless current_token.nil?
      results
    end

    private

    def next_char(enum)
      pos_line = @line
      pos_col = @column
      chr = enum.next
      @cur_line = pos_line
      @cur_col = pos_col
      if chr == "\n"
        @line = pos_line + 1
        @column = 1
      else
        @column = pos_col + 1
      end
      chr
    rescue StopIteration
      nil
    end

    def peek_char(enum)
      enum.peek
    rescue StopIteration
      nil
    end

    def read_string(enum, quote, line, column)
      content = quote
      loop do
        chr = next_char(enum)
        raise UnterminatedStringError, "Unterminated string: #{quote}" if chr.nil?

        content += chr
        break if chr == quote

        next unless chr == '\\'

        escaped = next_char(enum)
        raise UnterminatedStringError, "Unterminated string: #{quote}" if escaped.nil?

        content += escaped
      end
      Token.new(content, :string, line, column)
    end

    def read_number(enum, first, line, column)
      content = first

      # hex: 0x or 0X followed by at least one hex digit
      if first == '0'
        peeked = peek_char(enum)
        if peeked == 'x' || peeked == 'X'
          next_char(enum) # consume the x/X
          x_line = @cur_line
          x_col = @cur_col
          hex_body = read_hex(enum)
          return [Token.new(content, :number, line, column), Token.new(peeked, :text, x_line, x_col)] if hex_body.empty?

          content += peeked + hex_body
          return Token.new(content, :number, line, column)
        end
      end

      content += read_digits(enum)

      # fraction: . followed by a digit
      if peek_char(enum) == '.'
        next_char(enum) # consume the .
        dot_line = @cur_line
        dot_col = @cur_col
        if digit_char?(peek_char(enum))
          content += '.' + read_digits(enum)
        else
          # . not followed by a digit: put it back as a lone token
          return [Token.new(content, :number, line, column), Token.new('.', :lone, dot_line, dot_col)]
        end
      end

      # exponent: e or E, optional +/-, then at least one digit
      peeked = peek_char(enum)
      if peeked == 'e' || peeked == 'E'
        saved = peeked
        next_char(enum) # consume the e/E
        e_line = @cur_line
        e_col = @cur_col
        sign = peek_char(enum)
        consumed_sign = nil
        sign_line = nil
        sign_col = nil
        if sign == '+' || sign == '-'
          next_char(enum) # consume the sign
          consumed_sign = sign
          sign_line = @cur_line
          sign_col = @cur_col
        end
        if digit_char?(peek_char(enum))
          content += saved + (consumed_sign || '') + read_digits(enum)
        else
          # e/E (and optional sign) not followed by a digit: emit number, then the
          # consumed e/E and sign as separate tokens (already consumed from enum)
          fallback = [Token.new(content, :number, line, column), Token.new(saved, :text, e_line, e_col)]
          fallback << Token.new(consumed_sign, :lone, sign_line, sign_col) if consumed_sign
          return fallback
        end
      end

      Token.new(content, :number, line, column)
    end

    def read_hex(enum)
      digits = ''
      while hex_char?(peek_char(enum))
        digits += next_char(enum)
      end
      digits
    end

    def read_digits(enum)
      digits = ''
      while digit_char?(peek_char(enum))
        digits += next_char(enum)
      end
      digits
    end

    def hex_char?(chr)
      return false if chr.nil?

      digit_char?(chr) || ('a'..'f').cover?(chr) || ('A'..'F').cover?(chr)
    end

    def digit_char?(chr)
      !chr.nil? && digit_chars.include?(chr)
    end
  end
end
