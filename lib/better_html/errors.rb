require 'active_support/core_ext/string/output_safety'

module BetterHtml
  class InterpolatorError < RuntimeError; end
  class DontInterpolateHere < InterpolatorError; end
  class UnsafeHtmlError < InterpolatorError; end
  class HtmlError < RuntimeError; end

  class Errors
    delegate :[], :each, :size, :first,
      :empty?, :any?, :present?, to: :@errors

    def initialize
      @errors = []
    end

    def add(error)
      @errors << error
    end
  end
end
