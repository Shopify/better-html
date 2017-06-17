require 'test_helper'

module BetterHtml
  class NodeIteratorTest < ActiveSupport::TestCase
    test "consume cdata nodes" do
      tree = BetterHtml::NodeIterator.new("<![CDATA[ foo ]]>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::CData, tree.nodes.first.class
      assert_equal [" foo "], tree.nodes.first.content_parts.map(&:text)
    end

    test "unterminated cdata nodes are consumed until end" do
      tree = BetterHtml::NodeIterator.new("<![CDATA[ foo")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::CData, tree.nodes.first.class
      assert_equal [" foo"], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume cdata with interpolation" do
      tree = BetterHtml::NodeIterator.new("<![CDATA[ foo <%= bar %> baz ]]>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::CData, tree.nodes.first.class
      assert_equal [" foo ", "<%= bar %>", " baz "], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume comment nodes" do
      tree = BetterHtml::NodeIterator.new("<!-- foo -->")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Comment, tree.nodes.first.class
      assert_equal [" foo "], tree.nodes.first.content_parts.map(&:text)
    end

    test "unterminated comment nodes are consumed until end" do
      tree = BetterHtml::NodeIterator.new("<!-- foo")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Comment, tree.nodes.first.class
      assert_equal [" foo"], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume comment with interpolation" do
      tree = BetterHtml::NodeIterator.new("<!-- foo <%= bar %> baz -->")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Comment, tree.nodes.first.class
      assert_equal [" foo ", "<%= bar %>", " baz "], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume tag nodes" do
      tree = BetterHtml::NodeIterator.new("<div>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
      assert_equal false, tree.nodes.first.self_closing?
    end

    test "consume tag nodes with solidus" do
      tree = BetterHtml::NodeIterator.new("</div>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
      assert_equal true, tree.nodes.first.closing?
    end

    test "sets self_closing when appropriate" do
      tree = BetterHtml::NodeIterator.new("<div/>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
      assert_equal true, tree.nodes.first.self_closing?
    end

    test "consume tag nodes until name ends" do
      tree = BetterHtml::NodeIterator.new("<div/>")
      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)

      tree = BetterHtml::NodeIterator.new("<div ")
      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
    end

    test "consume tag nodes with interpolation" do
      tree = BetterHtml::NodeIterator.new("<ns:<%= name %>-thing>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Element, tree.nodes.first.class
      assert_equal ["ns:", "<%= name %>", "-thing"], tree.nodes.first.name_parts.map(&:text)
    end

    test "consume tag attributes nodes unquoted value" do
      tree = BetterHtml::NodeIterator.new("<div foo=bar>")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::NodeIterator::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::NodeIterator::Attribute, attribute.class
      assert_equal ["foo"], attribute.name_parts.map(&:text)
      assert_equal ["bar"], attribute.value_parts.map(&:text)
    end

    test "consume attributes without name" do
      tree = BetterHtml::NodeIterator.new("<div 'thing'>")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::NodeIterator::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::NodeIterator::Attribute, attribute.class
      assert_predicate attribute.name, :empty?
      assert_equal ["'", "thing", "'"], attribute.value_parts.map(&:text)
    end

    test "consume tag attributes nodes quoted value" do
      tree = BetterHtml::NodeIterator.new("<div foo=\"bar\">")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::NodeIterator::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::NodeIterator::Attribute, attribute.class
      assert_equal ["foo"], attribute.name_parts.map(&:text)
      assert_equal ['"', "bar", '"'], attribute.value_parts.map(&:text)
    end

    test "consume tag attributes nodes interpolation in name and value" do
      tree = BetterHtml::NodeIterator.new("<div data-<%= foo %>=\"some <%= value %> foo\">")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::NodeIterator::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::NodeIterator::Attribute, attribute.class
      assert_equal ["data-", "<%= foo %>"], attribute.name_parts.map(&:text)
      assert_equal ['"', "some ", "<%= value %>", " foo", '"'], attribute.value_parts.map(&:text)
    end

    test "attributes can be accessed through [] on Element object" do
      tree = BetterHtml::NodeIterator.new("<div foo=\"bar\">")

      assert_equal 1, tree.nodes.size
      element = tree.nodes.first
      assert_equal BetterHtml::NodeIterator::Element, element.class
      assert_equal 1, element.attributes.size
      assert_nil element['nonexistent']
      refute_nil attribute = element['foo']
      assert_equal BetterHtml::NodeIterator::Attribute, attribute.class
    end

    test "attribute values can be read unescaped" do
      tree = BetterHtml::NodeIterator.new("<div foo=\"&lt;&quot;&gt;\">")

      element = tree.nodes.first
      assert_equal 1, element.attributes.size
      attribute = element['foo']
      assert_equal '<">', attribute.unescaped_value
    end

    test "attribute values does not unescape stuff inside erb" do
      tree = BetterHtml::NodeIterator.new("<div foo=\"&lt;<%= &gt; %>&gt;\">")

      element = tree.nodes.first
      assert_equal 1, element.attributes.size
      attribute = element['foo']
      assert_equal '<<%= &gt; %>>', attribute.unescaped_value
    end

    test "consume text nodes" do
      tree = BetterHtml::NodeIterator.new("here is <%= some %> text")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Text, tree.nodes.first.class
      assert_equal ["here is ", "<%= some %>", " text"], tree.nodes.first.content_parts.map(&:text)
    end

    test "javascript template parsing works" do
      tree = BetterHtml::NodeIterator.new("here is <%= some %> text", template_language: :javascript)

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Text, tree.nodes.first.class
      assert_equal ["here is ", "<%= some %>", " text"], tree.nodes.first.content_parts.map(&:text)
    end

    test "javascript template does not consume html tags" do
      tree = BetterHtml::NodeIterator.new("<div <%= some %> />", template_language: :javascript)

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::NodeIterator::Text, tree.nodes.first.class
      assert_equal ["<div ", "<%= some %>", " />"], tree.nodes.first.content_parts.map(&:text)
    end

    test "lodash template parsing works" do
      tree = BetterHtml::NodeIterator.new('<div class="[%= foo %]">', template_language: :lodash)

      assert_equal 1, tree.nodes.size
      node = tree.nodes.first
      assert_equal BetterHtml::NodeIterator::Element, node.class
      assert_equal "div", node.name
      assert_equal 1, node.attributes.size
      attribute = node.attributes.first
      assert_equal "class", attribute.name
      assert_equal [:attribute_quoted_value_start, :expr_literal,
        :attribute_quoted_value_end], attribute.value_parts.map(&:type)
      assert_equal ["\"", "[%= foo %]", "\""], attribute.value_parts.map(&:text)
    end
  end
end
