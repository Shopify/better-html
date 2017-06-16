require 'test_helper'

module BetterHtml
  class TreeTest < ActiveSupport::TestCase
    test "consume cdata nodes" do
      tree = BetterHtml::Tree.new("<![CDATA[ foo ]]>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::CData, tree.nodes.first.class
      assert_equal [" foo "], tree.nodes.first.content_parts.map(&:text)
    end

    test "unterminated cdata nodes are consumed until end" do
      tree = BetterHtml::Tree.new("<![CDATA[ foo")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::CData, tree.nodes.first.class
      assert_equal [" foo"], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume cdata with interpolation" do
      tree = BetterHtml::Tree.new("<![CDATA[ foo <%= bar %> baz ]]>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::CData, tree.nodes.first.class
      assert_equal [" foo ", "<%= bar %>", " baz "], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume comment nodes" do
      tree = BetterHtml::Tree.new("<!-- foo -->")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Comment, tree.nodes.first.class
      assert_equal [" foo "], tree.nodes.first.content_parts.map(&:text)
    end

    test "unterminated comment nodes are consumed until end" do
      tree = BetterHtml::Tree.new("<!-- foo")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Comment, tree.nodes.first.class
      assert_equal [" foo"], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume comment with interpolation" do
      tree = BetterHtml::Tree.new("<!-- foo <%= bar %> baz -->")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Comment, tree.nodes.first.class
      assert_equal [" foo ", "<%= bar %>", " baz "], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume tag nodes" do
      tree = BetterHtml::Tree.new("<div>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
    end

    test "consume tag nodes with solidus" do
      tree = BetterHtml::Tree.new("</div>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
      assert_equal true, tree.nodes.first.closing?
    end

    test "consume tag nodes until name ends" do
      tree = BetterHtml::Tree.new("<div/>")
      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)

      tree = BetterHtml::Tree.new("<div ")
      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
    end

    test "consume tag nodes with interpolation" do
      tree = BetterHtml::Tree.new("<ns:<%= name %>-thing>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Element, tree.nodes.first.class
      assert_equal ["ns:", "<%= name %>", "-thing"], tree.nodes.first.name_parts.map(&:text)
    end

    test "consume tag attributes nodes unquoted value" do
      tree = BetterHtml::Tree.new("<div foo=bar>")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Tree::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Tree::Attribute, attribute.class
      assert_equal ["foo"], attribute.name_parts.map(&:text)
      assert_equal ["bar"], attribute.value_parts.map(&:text)
    end

    test "consume attributes without name" do
      tree = BetterHtml::Tree.new("<div 'thing'>")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Tree::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Tree::Attribute, attribute.class
      assert_predicate attribute.name, :empty?
      assert_equal ["'", "thing", "'"], attribute.value_parts.map(&:text)
    end

    test "consume tag attributes nodes quoted value" do
      tree = BetterHtml::Tree.new("<div foo=\"bar\">")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Tree::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Tree::Attribute, attribute.class
      assert_equal ["foo"], attribute.name_parts.map(&:text)
      assert_equal ['"', "bar", '"'], attribute.value_parts.map(&:text)
    end

    test "consume tag attributes nodes interpolation in name and value" do
      tree = BetterHtml::Tree.new("<div data-<%= foo %>=\"some <%= value %> foo\">")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Tree::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Tree::Attribute, attribute.class
      assert_equal ["data-", "<%= foo %>"], attribute.name_parts.map(&:text)
      assert_equal ['"', "some ", "<%= value %>", " foo", '"'], attribute.value_parts.map(&:text)
    end

    test "attributes can be accessed through [] on Element object" do
      tree = BetterHtml::Tree.new("<div foo=\"bar\">")

      assert_equal 1, tree.nodes.size
      element = tree.nodes.first
      assert_equal BetterHtml::Tree::Element, element.class
      assert_equal 1, element.attributes.size
      assert_nil element['nonexistent']
      refute_nil attribute = element['foo']
      assert_equal BetterHtml::Tree::Attribute, attribute.class
    end

    test "attribute values can be read unescaped" do
      tree = BetterHtml::Tree.new("<div foo=\"&lt;&quot;&gt;\">")

      element = tree.nodes.first
      assert_equal 1, element.attributes.size
      attribute = element['foo']
      assert_equal '<">', attribute.unescaped_value
    end

    test "attribute values does not unescape stuff inside erb" do
      tree = BetterHtml::Tree.new("<div foo=\"&lt;<%= &gt; %>&gt;\">")

      element = tree.nodes.first
      assert_equal 1, element.attributes.size
      attribute = element['foo']
      assert_equal '<<%= &gt; %>>', attribute.unescaped_value
    end

    test "consume text nodes" do
      tree = BetterHtml::Tree.new("here is <%= some %> text")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Text, tree.nodes.first.class
      assert_equal ["here is ", "<%= some %>", " text"], tree.nodes.first.content_parts.map(&:text)
    end

    test "javascript template parsing works" do
      tree = BetterHtml::Tree.new("here is <%= some %> text", template_language: :javascript)

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Text, tree.nodes.first.class
      assert_equal ["here is ", "<%= some %>", " text"], tree.nodes.first.content_parts.map(&:text)
    end

    test "javascript template does not consume html tags" do
      tree = BetterHtml::Tree.new("<div <%= some %> />", template_language: :javascript)

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Tree::Text, tree.nodes.first.class
      assert_equal ["<div ", "<%= some %>", " />"], tree.nodes.first.content_parts.map(&:text)
    end
  end
end
