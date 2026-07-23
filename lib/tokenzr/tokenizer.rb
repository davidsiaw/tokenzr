# frozen_string_literal: true

require 'set'

require 'tokenzr/error'
require 'tokenzr/charset'
require 'tokenzr/token'

module Tokenzr
  # main tokenizer class
  class Tokenizer
    def initialize(charset: nil, **overrides)
      base = charset || Charset.default
      @charset = merge_overrides(base, overrides)
      conflicts = @charset.conflicts
      raise ConfigurationError, "Charset conflict: #{format_conflicts(conflicts)}" unless conflicts.empty?

      validate_operators!
      build_operator_index
    end

    def text_chars
      @text_chars ||= @charset.to_sets[:text]
    end

    def digit_chars
      @digit_chars ||= @charset.to_sets[:digits]
    end

    def lone_chars
      @lone_chars ||= @charset.to_sets[:lone]
    end

    def space_chars
      @space_chars ||= @charset.to_sets[:space]
    end

    def string_quotes
      @string_quotes ||= @charset.to_sets[:quotes]
    end

    def parse(content)
      results = []
      current_token = nil
      enum = content.each_char
      @line = 1
      @column = 1
      @cur_line = 1
      @cur_col = 1
      @pushback = []

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
          op = match_operator(enum, chr, start_line, start_col)
          results << (op || Token.new(chr, :lone, start_line, start_col))
          next
        end

        raise UnknownCharError, "Unknown character: #{chr.inspect}"
      end

      results << current_token unless current_token.nil?
      results
    end

    private

    def merge_overrides(base, overrides)
      return base.dup unless overrides.any?

      Charset.new(
        text: overrides.fetch(:text, base.text),
        digits: overrides.fetch(:digits, base.digits),
        lone: overrides.fetch(:lone, base.lone),
        space: overrides.fetch(:space, base.space),
        quotes: overrides.fetch(:quotes, base.quotes),
        operators: overrides.fetch(:operators, base.operators)
      )
    end

    def format_conflicts(conflicts)
      conflicts.map { |c| "#{c.char.inspect} in #{c.sets.sort.join(', ')}" }.join('; ')
    end

    def validate_operators!
      return if @charset.operators.nil? || @charset.operators.empty?

      lone = lone_chars
      @charset.operators.each do |op|
        bad = op.chars.reject { |c| lone.include?(c) }
        next if bad.empty?

        raise ConfigurationError,
              "Operator #{op.inspect} contains chars not in the lone charset: #{bad.map(&:inspect).join(', ')}"
      end
    end

    def build_operator_index
      @operators_by_first = {}
      return if @charset.operators.nil? || @charset.operators.empty?

      @charset.operators.each do |op|
        next if op.length < 2 # single-char ops are handled by lone_chars

        (@operators_by_first[op[0]] ||= []) << op
      end
      # sort each group longest-first so the longest match wins
      @operators_by_first.transform_values! { |ops| ops.sort_by { |o| -o.length } }
    end

    def next_char(enum)
      if @pushback.any?
        chr, line, col = @pushback.pop
        @cur_line = line
        @cur_col = col
        if chr == "\n"
          @line = line + 1
          @column = 1
        else
          @line = line
          @column = col + 1
        end
        return chr
      end

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
      return @pushback.last[0] if @pushback.any?

      enum.peek
    rescue StopIteration
      nil
    end

    def push_back(chr, line, col)
      @pushback.push([chr, line, col])
    end

    def match_operator(enum, first, line, column)
      candidates = @operators_by_first[first]
      return nil unless candidates

      candidates.each do |op|
        rest = op[1..]
        consumed = []
        matched = true

        rest.each_char do |c|
          got = next_char(enum)
          break if got.nil?

          consumed << [got, @cur_line, @cur_col]
          next if got == c

          matched = false
          break
        end

        return Token.new(op, :lone, line, column) if matched && consumed.length == rest.length

        # push back consumed chars in reverse order
        consumed.reverse_each { |c, l, col| push_back(c, l, col) }
      end

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
        if ['x', 'X'].include?(peeked)
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
        unless digit_char?(peek_char(enum))
          return [Token.new(content, :number, line, column), Token.new('.', :lone, dot_line, dot_col)]
        end

        content += ".#{read_digits(enum)}"

        # . not followed by a digit: put it back as a lone token

      end

      # exponent: e or E, optional +/-, then at least one digit
      peeked = peek_char(enum)
      if ['e', 'E'].include?(peeked)
        saved = peeked
        next_char(enum) # consume the e/E
        e_line = @cur_line
        e_col = @cur_col
        sign = peek_char(enum)
        consumed_sign = nil
        sign_line = nil
        sign_col = nil
        if ['+', '-'].include?(sign)
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
      digits += next_char(enum) while hex_char?(peek_char(enum))
      digits
    end

    def read_digits(enum)
      digits = ''
      digits += next_char(enum) while digit_char?(peek_char(enum))
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
