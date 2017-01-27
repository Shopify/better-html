require 'ripper'
require 'pp'

module BetterHtml
  module TestHelper
    class RubyExpr
      attr_reader :calls

      BLOCK_EXPR = /\s*((\s+|\))do|\{)(\s*\|[^|]*\|)?\s*\Z/

      class ParseError < RuntimeError; end

      class MethodCall
        attr_accessor :instance, :method, :arguments
      end

      def initialize(code: nil, tree: nil)
        if code
          code = code.gsub(BLOCK_EXPR, '')
          tree = Ripper.sexp(code)
          raise ParseError, "cannot parse code" unless tree && tree.last.first.is_a?(Array)
          @tree = tree.last.first
        else
          @tree = tree
        end
        @calls = []
        parse!
      end

      private

      def parse!
        parse_expr(@tree)
      end

      def parse_expr(expr)
        case expr.first
        when :var_ref
          parse_expr(expr[1])
        when :paren
          parse_expr(expr[1].first)
        when :string_literal
          parse_expr(expr[1])
        when :string_content
          expr[1..-1].each do |subexpr|
            parse_expr(subexpr)
          end
        when :string_embexpr
          expr[1].each do |subexpr|
            parse_expr(subexpr)
          end
        when :assign, :massign
          parse_expr(expr[2])
        when :call
          @calls << obj = MethodCall.new
          obj.instance = expr[1]
          obj.method = parse_expr(expr[3])
          obj
        when :fcall, :vcall
          @calls << obj = MethodCall.new
          obj.method = parse_expr(expr[1])
          obj
        when :method_add_arg
          # foo(bar) -> foo=expr[1], bar=expr[2]
          obj = parse_expr(expr[1])
          obj.arguments = parse_expr(expr[2])
          obj
        when :command
          # foo bar -> foo=expr[1], bar=expr[2]
          @calls << obj = MethodCall.new
          obj.method = parse_expr(expr[1])
          obj.arguments = parse_expr(expr[2])
          obj
        when :arg_paren
          parse_expr(expr[1])
        when :if_mod, :unless_mod
          # foo if bar -> bar=expr[1], foo=expr[2]
          parse_expr(expr[2])
        when :ifop
          # foo ? bar : baz -> foo=expr[1], bar=expr[2], baz=expr[3]
          parse_expr(expr[2])
          parse_expr(expr[3])
        else
          expr[1]
        end
      end
    end
  end
end
