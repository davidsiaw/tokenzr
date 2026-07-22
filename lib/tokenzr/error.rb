# frozen_string_literal: true

module Tokenzr
  class Error < StandardError; end
  class UnknownCharError < Error; end
  class UnterminatedStringError < Error; end
end
