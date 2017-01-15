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
        @newline_pending += 1
      else
        src << "@output_buffer.safe_append='"
        src << "\n" * @newline_pending if @newline_pending > 0
        src << escape_text(text)
        src << "'.freeze;"

        @parser.parse(text)

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

      block_check(src, code) if code =~ BLOCK_EXPR
      super
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
        block_check(src, code)
        src << ".#{method_name}= " << code
      else
        src << ".#{method_name}=(" << code << ");"
      end
    end

    def parser_context
      if @parser.context == :attribute_value
        {
          tag_name: @parser.tag_name,
          attribute_name: @parser.attribute_name,
          attribute_value: @parser.attribute_value,
          attribute_quoted: @parser.attribute_quoted?,
        }
      elsif @parser.context == :attribute
        {
          tag_name: @parser.tag_name,
          attribute_name: @parser.attribute_name,
        }
      elsif @parser.context == :tag
        {
          tag_name: @parser.tag_name,
        }
      elsif @parser.context == :tag_name
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
      elsif @parser.context == :none
        {}
      else
        raise RuntimeError, "Tried to interpolate into unknown location #{@parser.context}."
      end
    end

    def block_check(src, code)
      unless @parser.context == :none
        raise BetterHtml::DontInterpolateHere, "Block not allowed at this location."
      end
    end
  end
end
