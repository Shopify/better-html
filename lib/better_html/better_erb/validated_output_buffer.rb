class BetterHtml::BetterErb
  class ValidatedOutputBuffer
    def initialize(buffer)
      @output = String.new(buffer.to_s)
      @parser = HtmlTokenizer::Parser.new
      @interpolator = BetterHtml::BetterErb::Interpolator.new(@parser)
    end

    def safe_append=(text)
      return if text.nil?

      # Append html from the template body to the buffer, as-is.
      @parser.parse(text)

    rescue => e
      puts "#{e.message}"
      puts "#{e.backtrace.join("\n")}"
      raise
    ensure
      @output << text unless text.nil?
    end

    def <<(text)
      return if text.nil?

      # Appends the result of some erb code being called.
      # Escape the result unless it is marked as html_safe.
      as_str = @interpolator.to_safe_value(text, "<%= your code %>", true)
      @parser.parse(as_str)

    rescue => e
      puts "#{e.message}"
      puts "#{e.backtrace.join("\n")}"
      raise
    ensure
      @output << as_str unless as_str.nil?
    end
    alias :append= :<<

    def safe_expr_append=(text)
      return if text.nil?

      # Same as safe_append= but for a ruby expression.
      # Do not escape the result, it is deemed to be safe already.
      as_str = @interpolator.to_safe_value(text, "<%= your code %>", false)
      @parser.parse(as_str)

    rescue => e
      puts "#{e.message}"
      puts "#{e.backtrace.join("\n")}"
      raise
    ensure
      @output << as_str unless as_str.nil?
    end

    def html_safe?
      true
    end

    def html_safe
      self.class.new(@output)
    end

    def to_s
      @output.html_safe
    end
  end
end
