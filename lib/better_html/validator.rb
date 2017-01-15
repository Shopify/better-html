require 'action_view'

module BetterHtml
  class Validator
    attr_reader :document, :errors

    def initialize
      @tokenizer = HtmlTokenizer::Tokenizer.new
      @nodes = []
      @text = nil # 'text' argument passed to parse()
      @line = nil # current line number
      @node = nil # current node
      @context = :document # current context
      @errors = []
    end

    def parse(text, start_line:)
      @line = start_line
      @text = text
      @text.each_line do |line|
        @tokenizer.tokenize(text) do |*args|
          public_send("parse_#{@context}", *args)
        end
        @line += 1
      end
    end

    def validate
      @nodes.each do |node|
        node.validate
        node.errors do |error|
          @errors << error
        end
      end
    end

    def extract(start, stop)
      @text[start..stop]
    end

    def push(node)
      @node = node
      @nodes << node
    end

    def parse_document(type, *edges)
      token = Token.new(type, extract(*edges))
      case type
      when :text
        push Text.new(token, @line)
      when :comment_start
        @context = :comment
        push Comment.new(token, @line)
      when :tag_start
        @context = :tag
        push Tag.new(token, @line)
      when :cdata_start
        @context = :cdata
        push CData.new(token, @line)
      when :malformed
        push Malformed.new(token, @line)
      end
    end

    def parse_comment(type, *edges)
      @node << Token.new(type, extract(*edges))
      @context = :document if type == :comment_end
    end

    def parse_tag(type, *edges)
      @node << Token.new(type, extract(*edges))
      @context = :document if type == :tag_end
    end

    def parse_cdata(type, *edges)
      @node << Token.new(type, extract(*edges))
      @context = :document if type == :cdata_end
    end

    class Token
      attr_accessor :type, :text

      def initialize(type, text)
        @type = type
        @text = text
      end

      def to_s
        @text
      end
    end

    class TokenList
      attr_accessor :tokens, :line_number, :errors

      def initialize(token, line_number)
        @tokens = [token]
        @line_number = line_number
        @errors = []
      end

      def <<(token)
        @tokens << token
      end

      def each
        @tokens.each do |token|
          yield(token)
        end
      end

      def to_s
        @tokens.map(&:to_s).join
      end

      def validate
        @tokens.each do |token|
          if token.type == :malformed
            @errors << TokenError.new(self, "Malformed data")
          end
        end
      end
    end

    class Text < TokenList
    end

    class Comment < TokenList
      def validate
        super
        unless @tokens[-1].type == :comment_end
          @errors << TokenError.new(self, "Unclosed comment tag")
        end
      end
    end

    class Tag < TokenList
    end

    class CData < TokenList
    end

    class Malformed < TokenList
    end

    class TokenError < RuntimeError
      attr_reader :token

      def initialize(token, message)
        @token = token
        super(message)
      end

      def to_s
        s = "#{message}.\n"
        s << "In '#{@token.class}' on line #{@token.line_number}\n"
        s << "  #{@token.lines.join("\n  ")}\n"
      end
    end
  end
end
