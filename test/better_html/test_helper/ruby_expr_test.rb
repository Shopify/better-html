require 'test_helper'
require 'better_html/test_helper/ruby_expr'

module BetterHtml
  module TestHelper
    class RubyExprTest < ActiveSupport::TestCase
      test "simple call" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("foo")
        assert_equal 1, expr.calls.size
        assert_nil expr.calls.first.instance
        assert_equal :foo, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "instance call" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("foo.bar")
        assert_equal 1, expr.calls.size
        assert_equal 's(:send, nil, :foo)', expr.calls.first.instance.inspect
        assert_equal :bar, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "instance call with arguments" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("foo(x).bar")
        assert_equal 1, expr.calls.size
        assert_equal "s(:send, nil, :foo,\n  s(:send, nil, :x))", expr.calls.first.instance.inspect
        assert_equal :bar, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "instance call with parenthesis" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("(foo).bar")
        assert_equal 1, expr.calls.size
        assert_equal "s(:begin,\n  s(:send, nil, :foo))", expr.calls.first.instance.inspect
        assert_equal :bar, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "instance call with parenthesis 2" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("(foo)")
        assert_equal 1, expr.calls.size
        assert_nil expr.calls.first.instance
        assert_equal :foo, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "command call" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("foo bar")
        assert_equal 1, expr.calls.size
        assert_nil expr.calls.first.instance
        assert_equal :foo, expr.calls.first.method
        assert_equal '[s(:send, nil, :bar)]', expr.calls.first.arguments.inspect
        refute_predicate expr, :static_value?
      end

      test "command call with block" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("foo bar do")
        assert_equal 1, expr.calls.size
        assert_nil expr.calls.first.instance
        assert_equal :foo, expr.calls.first.method
        assert_equal '[s(:send, nil, :bar)]', expr.calls.first.arguments.inspect
        refute_predicate expr, :static_value?
      end

      test "call with parameters" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("foo(bar)")
        assert_equal 1, expr.calls.size
        assert_nil expr.calls.first.instance
        assert_equal :foo, expr.calls.first.method
        assert_equal '[s(:send, nil, :bar)]', expr.calls.first.arguments.inspect
        refute_predicate expr, :static_value?
      end

      test "instance call with parameters" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("foo.bar(baz, x)")
        assert_equal 1, expr.calls.size
        assert_equal 's(:send, nil, :foo)', expr.calls.first.instance.inspect
        assert_equal :bar, expr.calls.first.method
        assert_equal '[s(:send, nil, :baz), s(:send, nil, :x)]', expr.calls.first.arguments.inspect
        refute_predicate expr, :static_value?
      end

      test "call with parameters with if conditional modifier" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("foo(bar) if something?")
        assert_equal 1, expr.calls.size
        assert_nil expr.calls.first.instance
        assert_equal :foo, expr.calls.first.method
        assert_equal '[s(:send, nil, :bar)]', expr.calls.first.arguments.inspect
        refute_predicate expr, :static_value?
      end

      test "call with parameters with unless conditional modifier" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("foo(bar) unless something?")
        assert_equal 1, expr.calls.size
        assert_nil expr.calls.first.instance
        assert_equal :foo, expr.calls.first.method
        assert_equal '[s(:send, nil, :bar)]', expr.calls.first.arguments.inspect
        refute_predicate expr, :static_value?
      end

      test "expression call in ternary" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("something? ? foo : bar")
        assert_equal 2, expr.calls.size
        refute_predicate expr, :static_value?

        assert_nil expr.calls[0].instance
        assert_equal :foo, expr.calls[0].method
        assert_equal [], expr.calls[0].arguments

        assert_nil expr.calls[1].instance
        assert_equal :bar, expr.calls[1].method
        assert_equal [], expr.calls[1].arguments
      end

      test "expression call with args in ternary" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("something? ? foo(x) : bar(x)")
        assert_equal 2, expr.calls.size

        assert_nil expr.calls[0].instance
        assert_equal :foo, expr.calls[0].method
        assert_equal '[s(:send, nil, :x)]', expr.calls[0].arguments.inspect

        assert_nil expr.calls[1].instance
        assert_equal :bar, expr.calls[1].method
        assert_equal '[s(:send, nil, :x)]', expr.calls[1].arguments.inspect
        refute_predicate expr, :static_value?
      end

      test "string without interpolation" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('"foo"')
        assert_equal 0, expr.calls.size
        assert_predicate expr, :static_value?
      end

      test "string with interpolation" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('"foo #{bar}"')
        assert_equal 1, expr.calls.size
        assert_nil expr.calls.first.instance
        assert_equal :bar, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "ternary in string with interpolation" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('"foo #{foo? ? bar : baz}"')
        assert_equal 2, expr.calls.size

        assert_nil expr.calls.first.instance
        assert_equal :bar, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments

        assert_nil expr.calls.last.instance
        assert_equal :baz, expr.calls.last.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "assignment to variable" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('x = foo.bar')
        assert_equal 1, expr.calls.size
        assert_equal 's(:send, nil, :foo)', expr.calls.first.instance.inspect
        assert_equal :bar, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "assignment to variable with command call" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('raw x = foo.bar')
        assert_equal 1, expr.calls.size
        assert_nil expr.calls.first.instance
        assert_equal :raw, expr.calls.first.method
        assert_equal "[s(:lvasgn, :x,\n  s(:send,\n    s(:send, nil, :foo), :bar))]", expr.calls.first.arguments.inspect
        refute_predicate expr, :static_value?
      end

      test "assignment with instance call" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('(x = foo).bar')
        assert_equal 1, expr.calls.size
        assert_equal "s(:begin,\n  s(:lvasgn, :x,\n    s(:send, nil, :foo)))", expr.calls.first.instance.inspect
        assert_equal :bar, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "assignment to multiple variables" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('x, y = foo.bar')
        assert_equal 1, expr.calls.size
        assert_equal 's(:send, nil, :foo)', expr.calls.first.instance.inspect
        assert_equal :bar, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "safe navigation operator" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('foo&.bar')
        assert_equal 1, expr.calls.size
        assert_equal 's(:send, nil, :foo)', expr.calls[0].instance.inspect
        assert_equal :bar, expr.calls[0].method
        assert_equal [], expr.calls[0].arguments
        refute_predicate expr, :static_value?
      end

      test "instance variable" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('@foo')
        assert_equal 0, expr.calls.size
        refute_predicate expr, :static_value?
      end

      test "instance method on variable" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('@foo.bar')
        assert_equal 1, expr.calls.size
        assert_equal 's(:ivar, :@foo)', expr.calls.first.instance.inspect
        assert_equal :bar, expr.calls.first.method
        assert_equal [], expr.calls.first.arguments
        refute_predicate expr, :static_value?
      end

      test "index into array" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('local_assigns[:text_class] if local_assigns[:text_class]')
        assert_equal 1, expr.calls.size
        assert_equal 's(:send, nil, :local_assigns)', expr.calls.first.instance.inspect
        assert_equal :[], expr.calls.first.method
        assert_equal '[s(:sym, :text_class)]', expr.calls.first.arguments.inspect
        refute_predicate expr, :static_value?
      end

      test "static_value? for ivar" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('@foo')
        refute_predicate expr, :static_value?
      end

      test "static_value? for str" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("'str'")
        assert_predicate expr, :static_value?
      end

      test "static_value? for int" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("1")
        assert_predicate expr, :static_value?
      end

      test "static_value? for bool" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("true")
        assert_predicate expr, :static_value?
      end

      test "static_value? for nil" do
        expr = BetterHtml::TestHelper::RubyExpr.parse("nil")
        assert_predicate expr, :static_value?
      end

      test "static_value? for dstr without interpolate" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('"str"')
        assert_predicate expr, :static_value?
      end

      test "static_value? for dstr with interpolate" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('"str #{foo}"')
        refute_predicate expr, :static_value?
      end

      test "static_value? with safe ternary" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('foo ? \'a\' : \'b\'')
        assert_predicate expr, :static_value?
      end

      test "static_value? with safe conditional" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('\'foo\' if bar?')
        assert_predicate expr, :static_value?
      end

      test "static_value? with safe assignment" do
        expr = BetterHtml::TestHelper::RubyExpr.parse('x = \'foo\'')
        assert_predicate expr, :static_value?
      end
    end
  end
end
