require 'test_helper'

module BetterHtml
  class TreeTest < ActiveSupport::TestCase
    test "consume cdata nodes" do
      tree = BetterHtml::Tree.new("<![CDATA[ foo ]]>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::CData, tree.nodes.first.class
      assert_equal [" foo "], tree.nodes.first.content.map(&:text)
    end

    test "unterminated cdata nodes are consumed until end" do
      tree = BetterHtml::Tree.new("<![CDATA[ foo")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::CData, tree.nodes.first.class
      assert_equal [" foo"], tree.nodes.first.content.map(&:text)
    end

    test "consume cdata with interpolation" do
      tree = BetterHtml::Tree.new("<![CDATA[ foo <%= bar %> baz ]]>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::CData, tree.nodes.first.class
      assert_equal [" foo ", "<%= bar %>", " baz "], tree.nodes.first.content.map(&:text)
    end

    test "consume comment nodes" do
      tree = BetterHtml::Tree.new("<!-- foo -->")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Comment, tree.nodes.first.class
      assert_equal [" foo "], tree.nodes.first.content.map(&:text)
    end

    test "unterminated comment nodes are consumed until end" do
      tree = BetterHtml::Tree.new("<!-- foo")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Comment, tree.nodes.first.class
      assert_equal [" foo"], tree.nodes.first.content.map(&:text)
    end

    test "consume comment with interpolation" do
      tree = BetterHtml::Tree.new("<!-- foo <%= bar %> baz -->")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Comment, tree.nodes.first.class
      assert_equal [" foo ", "<%= bar %>", " baz "], tree.nodes.first.content.map(&:text)
    end

    test "consume tag nodes" do
      tree = BetterHtml::Tree.new("<div>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Tag, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name.map(&:text)
    end

    test "consume tag nodes with solidus" do
      tree = BetterHtml::Tree.new("</div>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Tag, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name.map(&:text)
      assert_equal true, tree.nodes.first.closing?
    end

    test "consume tag nodes until name ends" do
      tree = BetterHtml::Tree.new("<div/>")
      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Tag, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name.map(&:text)

      tree = BetterHtml::Tree.new("<div ")
      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Tag, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name.map(&:text)
    end

    test "consume tag nodes with interpolation" do
      tree = BetterHtml::Tree.new("<ns:<%= name %>-thing>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Tag, tree.nodes.first.class
      assert_equal ["ns:", "<%= name %>", "-thing"], tree.nodes.first.name.map(&:text)
    end

    test "consume tag attributes nodes unquoted value" do
      tree = BetterHtml::Tree.new("<div foo=bar>")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Tree::Tag, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Tree::Attribute, attribute.class
      assert_equal ["foo"], attribute.name.map(&:text)
      assert_equal ["bar"], attribute.value.map(&:text)
    end

    test "consume tag attributes nodes quoted value" do
      tree = BetterHtml::Tree.new("<div foo=\"bar\">")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Tree::Tag, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Tree::Attribute, attribute.class
      assert_equal ["foo"], attribute.name.map(&:text)
      assert_equal ['"', "bar", '"'], attribute.value.map(&:text)
    end

    test "consume tag attributes nodes interpolation in name and value" do
      tree = BetterHtml::Tree.new("<div data-<%= foo %>=\"some <%= value %> foo\">")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Tree::Tag, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Tree::Attribute, attribute.class
      assert_equal ["data-", "<%= foo %>"], attribute.name.map(&:text)
      assert_equal ['"', "some ", "<%= value %>", " foo", '"'], attribute.value.map(&:text)
    end

    test "consume text nodes" do
      tree = BetterHtml::Tree.new("here is <%= some %> text")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Text, tree.nodes.first.class
      assert_equal ["here is ", "<%= some %>", " text"], tree.nodes.first.content.map(&:text)
    end
  end
end
