require 'test_helper'
require 'better_html/test_helper/ruby_expr'

module BetterHtml
  module TestHelper
    class RubyExprTest < ActiveSupport::TestCase
      test "simple call" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "foo")
        assert_equal 1, expr.calls.size
        assert_equal nil, expr.calls.first.instance
        assert_equal "foo", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "instance call" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "foo.bar")
        assert_equal 1, expr.calls.size
        assert_equal [:vcall, [:@ident, "foo", [1, 0]]], expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "instance call with arguments" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "foo(x).bar")
        assert_equal 1, expr.calls.size
        assert_equal [:method_add_arg, [:fcall, [:@ident, "foo", [1, 0]]], [:arg_paren, [:args_add_block, [[:vcall, [:@ident, "x", [1, 4]]]], false]]], expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "instance call with parenthesis" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "(foo).bar")
        assert_equal 1, expr.calls.size
        assert_equal [:paren, [[:vcall, [:@ident, "foo", [1, 1]]]]], expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "instance call with parenthesis 2" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "(foo)")
        assert_equal 1, expr.calls.size
        assert_equal nil, expr.calls.first.instance
        assert_equal "foo", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "command call" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "foo bar")
        assert_equal 1, expr.calls.size
        assert_equal nil, expr.calls.first.instance
        assert_equal "foo", expr.calls.first.method
        assert_equal [[:vcall, [:@ident, "bar", [1, 4]]]], expr.calls.first.arguments
      end

      test "command call with block" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "foo bar do")
        assert_equal 1, expr.calls.size
        assert_equal nil, expr.calls.first.instance
        assert_equal "foo", expr.calls.first.method
        assert_equal [[:vcall, [:@ident, "bar", [1, 4]]]], expr.calls.first.arguments
      end

      test "call with parameters" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "foo(bar)")
        assert_equal 1, expr.calls.size
        assert_equal nil, expr.calls.first.instance
        assert_equal "foo", expr.calls.first.method
        assert_equal [[:vcall, [:@ident, "bar", [1, 4]]]], expr.calls.first.arguments
      end

      test "instance call with parameters" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "foo.bar(baz, x)")
        assert_equal 1, expr.calls.size
        assert_equal [:vcall, [:@ident, "foo", [1, 0]]], expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal [[:vcall, [:@ident, "baz", [1, 8]]], [:vcall, [:@ident, "x", [1, 13]]]], expr.calls.first.arguments
      end

      test "call with parameters with if conditional modifier" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "foo(bar) if something?")
        assert_equal 1, expr.calls.size
        assert_equal nil, expr.calls.first.instance
        assert_equal "foo", expr.calls.first.method
        assert_equal [[:vcall, [:@ident, "bar", [1, 4]]]], expr.calls.first.arguments
      end

      test "call with parameters with unless conditional modifier" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "foo(bar) unless something?")
        assert_equal 1, expr.calls.size
        assert_equal nil, expr.calls.first.instance
        assert_equal "foo", expr.calls.first.method
        assert_equal [[:vcall, [:@ident, "bar", [1, 4]]]], expr.calls.first.arguments
      end

      test "expression call in ternary" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "something? ? foo : bar")
        assert_equal 2, expr.calls.size

        assert_equal nil, expr.calls.first.instance
        assert_equal "foo", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments

        assert_equal nil, expr.calls.last.instance
        assert_equal "bar", expr.calls.last.method
        assert_equal nil, expr.calls.last.arguments
      end

      test "expression call with args in ternary" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: "something? ? foo(x) : bar(x)")
        assert_equal 2, expr.calls.size

        assert_equal nil, expr.calls.first.instance
        assert_equal "foo", expr.calls.first.method
        assert_equal [[:vcall, [:@ident, "x", [1, 17]]]], expr.calls.first.arguments

        assert_equal nil, expr.calls.last.instance
        assert_equal "bar", expr.calls.last.method
        assert_equal [[:vcall, [:@ident, "x", [1, 26]]]], expr.calls.last.arguments
      end

      test "string without interpolation" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: '"foo"')
        assert_equal 0, expr.calls.size
      end

      test "string with interpolation" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: '"foo #{bar}"')
        assert_equal 1, expr.calls.size
        assert_equal nil, expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "ternary in string with interpolation" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: '"foo #{foo? ? bar : baz}"')
        assert_equal 2, expr.calls.size

        assert_equal nil, expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments

        assert_equal nil, expr.calls.last.instance
        assert_equal "baz", expr.calls.last.method
        assert_equal nil, expr.calls.last.arguments
      end

      test "assignment to variable" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: 'x = foo.bar')
        assert_equal 1, expr.calls.size
        assert_equal [:vcall, [:@ident, "foo", [1, 4]]], expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "assignment to variable with command call" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: 'raw x = foo.bar')
        assert_equal 1, expr.calls.size
        assert_equal nil, expr.calls.first.instance
        assert_equal "raw", expr.calls.first.method
        assert_equal [[:assign, [:var_field, [:@ident, "x", [1, 4]]], [:call, [:vcall, [:@ident, "foo", [1, 8]]], :".", [:@ident, "bar", [1, 12]]]]], expr.calls.first.arguments
      end

      test "assignment with instance call" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: '(x = foo).bar')
        assert_equal 1, expr.calls.size
        assert_equal [:paren, [[:assign, [:var_field, [:@ident, "x", [1, 1]]], [:vcall, [:@ident, "foo", [1, 5]]]]]], expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "assignment to multiple variables" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: 'x, y = foo.bar')
        assert_equal 1, expr.calls.size
        assert_equal [:vcall, [:@ident, "foo", [1, 7]]], expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "safe navigation operator" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: 'foo&.bar')
        assert_equal 1, expr.calls.size
        assert_equal [:vcall, [:@ident, "foo", [1, 0]]], expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "instance variable" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: '@foo')
        assert_equal 0, expr.calls.size
      end

      test "instance method on variable" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: '@foo.bar')
        assert_equal 1, expr.calls.size
        assert_equal [:var_ref, [:@ivar, "@foo", [1, 0]]], expr.calls.first.instance
        assert_equal "bar", expr.calls.first.method
        assert_equal nil, expr.calls.first.arguments
      end

      test "index into array" do
        expr = BetterHtml::TestHelper::RubyExpr.new(code: 'local_assigns[:text_class] if local_assigns[:text_class]')
        assert_equal 0, expr.calls.size
      end
    end
  end
end
