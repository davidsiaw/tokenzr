# frozen_string_literal: true

module Tokenzr
  # token representation
  class Token
    attr_reader :content, :type, :line, :column

    def initialize(content = nil, type = nil, line = nil, column = nil)
      @content = content
      @type = type
      @line = line
      @column = column
    end
  end
end
