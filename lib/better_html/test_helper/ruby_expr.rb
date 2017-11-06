require 'parser/current'

module BetterHtml
  module TestHelper
    class RubyExpr
      BLOCK_EXPR = /\s*((\s+|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/

      class ParseError < RuntimeError; end

      class MethodCall
        attr_accessor :instance, :method, :arguments

        def initialize(instance, method, arguments)
          @instance = instance
          @method = method
          @arguments = arguments
        end

        def self.from_ast_node(node)
          new(node.children[0], node.children[1], node.children[2..-1])
        end
      end

      def initialize(ast)
        raise ArgumentError, "expect first argument to be Parser::AST::Node" unless ast.is_a?(Parser::AST::Node)
        @ast = ast
      end

      def self.parse(code)
        parser = Parser::CurrentRuby.new
        parser.diagnostics.consumer = lambda { |diag| }
        buf = Parser::Source::Buffer.new('(string)')
        buf.source = code.sub(BLOCK_EXPR, '')
        parsed = parser.parse(buf)
        raise ParseError, "error parsing code: #{code.inspect}" unless parsed
        new(parsed)
      end

      def start
        @ast.loc.expression.begin_pos
      end

      def end
        @ast.loc.expression.end_pos
      end

      def traverse(current=@ast, only: nil, &block)
        yield current if node_match?(current, only)
        each_child_node(current) do |child|
          traverse(child, only: only, &block)
        end
      end

      def each_child_node(current=@ast, only: nil, range: (0..-1))
        current.children[range].each do |child|
          if child.is_a?(Parser::AST::Node) && node_match?(child, only)
            yield child
          end
        end
      end

      def node_match?(current, type)
        type.nil? || Array[type].flatten.include?(current.type)
      end

      STATIC_TYPES = [:str, :int, :true, :false, :nil]

      def each_return_value_recursive(current=@ast, only: nil, &block)
        case current.type
        when :send, :csend, :ivar, *STATIC_TYPES
          yield current if node_match?(current, only)
        when :if, :masgn, :lvasgn
          # first child is ignored as it does not contain return values
          # for example, in `foo ? x : y` we only care about x and y, not foo
          each_child_node(current, range: 1..-1) do |child|
            each_return_value_recursive(child, only: only, &block)
          end
        else
          each_child_node(current) do |child|
            each_return_value_recursive(child, only: only, &block)
          end
        end
      end

      def static_value?
        returns = []
        each_return_value_recursive do |node|
          returns << node
        end
        return false if returns.size == 0
        returns.each do |node|
          if STATIC_TYPES.include?(node.type)
            next
          elsif node.type == :dstr
            each_child_node(node) do |child|
              return false if child.type != :str
            end
          else
            return false
          end
        end
        true
      end

      def calls
        calls = []
        each_return_value_recursive(only: [:send, :csend]) do |node|
          calls << MethodCall.from_ast_node(node)
        end
        calls
      end
    end
  end
end
