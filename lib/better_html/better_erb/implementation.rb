require 'html_tokenizer'
require 'action_view'

class BetterHtml::BetterErb
  class Implementation < ActionView::Template::Handlers::Erubis
    def initialize(*)
      @parser = HtmlTokenizer::Parser.new
      @newline_pending = 0
      super
    end

    def add_preamble(src)
      src << "@output_buffer = (output_buffer.presence || ActionView::OutputBuffer.new);"
    end

    def add_text(src, text)
      return if text.empty?

      if text == "\n"
        @parser.parse("\n")
        @newline_pending += 1
      else
        src << "@output_buffer.safe_append='"
        src << "\n" * @newline_pending if @newline_pending > 0
        src << escape_text(text)
        src << "'.freeze;"

        @parser.parse(text) do |*args|
          check_token(*args)
        end

        @newline_pending = 0
      end
    end

    def add_expr_literal(src, code)
      add_expr_auto_escaped(src, code, true)
    end

    def add_expr_escaped(src, code)
      add_expr_auto_escaped(src, code, false)
    end

    def add_stmt(src, code)
      flush_newline_if_pending(src)

      block_check(src, "<%#{code}%>")
      @parser.append_placeholder(code)
      super
    end

    def validate!
      check_parser_errors

      unless @parser.context == :none
        raise BetterHtml::HtmlError, 'Detected an open tag at the end of this document.'
      end
    end

    private

    def class_name
      "BetterHtml::BetterErb::ValidatedOutputBuffer"
    end

    def wrap_method
      "#{class_name}.wrap"
    end

    def add_expr_auto_escaped(src, code, auto_escape)
      flush_newline_if_pending(src)

      src << "#{wrap_method}(@output_buffer, (#{parser_context.inspect}), '#{escape_text(code)}'.freeze, #{auto_escape})"
      method_name = "safe_#{@parser.context}_append"
      if code =~ BLOCK_EXPR
        block_check(src, "<%=#{code}%>")
        src << ".#{method_name}= " << code
      else
        src << ".#{method_name}=(" << code << ");"
      end
      @parser.append_placeholder("<%=#{code}%>")
    end

    def parser_context
      if [:quoted_value, :unquoted_value, :space_after_attribute].include?(@parser.context)
        {
          tag_name: @parser.tag_name,
          attribute_name: @parser.attribute_name,
          attribute_value: @parser.attribute_value,
          attribute_quoted: @parser.attribute_quoted?,
        }
      elsif [:attribute_name, :after_attribute_name, :after_equal].include?(@parser.context)
        {
          tag_name: @parser.tag_name,
          attribute_name: @parser.attribute_name,
        }
      elsif [:tag, :tag_name, :tag_end].include?(@parser.context)
        {
          tag_name: @parser.tag_name,
        }
      elsif @parser.context == :rawtext
        {
          tag_name: @parser.tag_name,
          rawtext_text: @parser.rawtext_text,
        }
      elsif @parser.context == :comment
        {
          comment_text: @parser.comment_text,
        }
      elsif [:none, :solidus_or_tag_name].include?(@parser.context)
        {}
      else
        raise RuntimeError, "Tried to interpolate into unknown location #{@parser.context}."
      end
    end

    def block_check(src, code)
      unless @parser.context == :none || @parser.context == :rawtext
        s = "Ruby statement not allowed.\n"
        s << "In '#{@parser.context}' on line #{@parser.line_number} column #{@parser.column_number}:\n"
        prefix = extract_line(@parser.line_number)
        code = code.lines.first
        s << "#{prefix}#{code}\n"
        s << "#{' ' * prefix.size}#{'^' * code.size}"
        raise BetterHtml::DontInterpolateHere, s
      end
    end

    def check_parser_errors
      errors = @parser.errors
      return if errors.empty?

      s = "#{errors.size} error(s) found in HTML document.\n"
      errors.each do |error|
        s = "#{error.message}\n"
        s << "On line #{error.line} column #{error.column}:\n"
        line = extract_line(error.line)
        s << "#{line}\n"
        s << "#{' ' * (error.column)}#{'^' * (line.size - error.column)}"
      end

      raise BetterHtml::HtmlError, s
    end

    def check_token(type, start, stop, line, column)
      if type == :tag_name
        text = @parser.extract(start, stop)
        unless BetterHtml.config.partial_tag_name_pattern === text
          s = "Invalid tag name #{text.inspect} does not match "\
            "regular expression #{BetterHtml.config.partial_tag_name_pattern.inspect}\n"
          s << "On line #{line} column #{column}:\n"
          line = extract_line(line)
          s << "#{line}\n"
          s << "#{' ' * column}#{'^' * (text.size)}"
          raise BetterHtml::HtmlError, s
        end
      end
    end

    def extract_line(line)
      @parser.document.lines[line-1]
    end
  end
end
