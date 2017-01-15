require 'active_support/core_ext/string/output_safety'

module BetterHtml
  class InterpolatorError < RuntimeError; end
  class DontInterpolateHere < InterpolatorError; end
  class UnsafeHtmlError < InterpolatorError; end
  class HtmlError < RuntimeError; end
end
