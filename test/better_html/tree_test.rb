require 'test_helper'

module BetterHtml
  class TreeTest < ActiveSupport::TestCase
    test "simple node" do
      tree = Tree.new("<div></div>")
      assert_predicate tree.errors, :empty?

      assert_equal 1, tree.root.size
      assert_equal 'div', tree.root[0].name
      assert_equal true, tree.root[0].closed?
      assert_equal false, tree.root[0].self_closing?
    end

    test "simple self-closing node" do
      tree = Tree.new("<meta />")
      assert_predicate tree.errors, :empty?

      assert_equal 1, tree.root.size
      assert_equal 'meta', tree.root[0].name
      assert_equal true, tree.root[0].closed?
      assert_equal true, tree.root[0].self_closing?
    end

    test "mismatched closing tag" do
      tree = Tree.new("<div></p></div>")
      assert_equal 1, tree.errors.size
      assert_equal "mismatched </p> in <div> element", tree.errors[0].message

      assert_equal 1, tree.root.size
      assert_equal 'div', tree.root[0].name
      assert_equal true, tree.root[0].closed?
      assert_equal false, tree.root[0].self_closing?
    end

    test "mismatched closing tag at root" do
      tree = Tree.new("</p>")
      assert_equal 1, tree.errors.size
      assert_equal "mismatched </p> at root of tree", tree.errors[0].message

      assert_predicate tree.root, :empty?
    end

    test "node with text content" do
      tree = Tree.new("<div>text</div>")
      assert_predicate tree.errors, :empty?

      assert_equal 1, tree.root.size
      div = tree.root[0]
      assert_equal 1, div.size
      assert_equal 'text', div[0].content
    end

    test "extract erb from text node" do
      tree = Tree.new("<div>before<%= foo %>after</div>")
      assert_predicate tree.errors, :empty?

      assert_equal 1, tree.root.size
      div = tree.root[0]
      assert_equal 1, div.size
      text = div[0]
      assert_equal 3, text.content_parts.size
      assert_equal 'before', text.content_parts[0].text
      assert_equal '<%= foo %>', text.content_parts[1].text
      assert_equal ' foo ', text.content_parts[1].code
      assert_equal 'after', text.content_parts[2].text
    end

    test "closing tag for void element" do
      tree = Tree.new("<br></br>")
      assert_equal 1, tree.errors.size
      assert_equal "end of tag for void element: </br>", tree.errors[0].message

      assert_equal 1, tree.root.size
      assert_equal 'br', tree.root[0].name
      assert_equal true, tree.root[0].closed?
      assert_equal false, tree.root[0].self_closing?
      assert_equal true, tree.root[0].void?
    end

    test "properly self-closed void element" do
      tree = Tree.new("<br/>")
      assert_predicate tree.errors, :empty?

      assert_equal 1, tree.root.size
      assert_equal 'br', tree.root[0].name
      assert_equal true, tree.root[0].closed?
      assert_equal true, tree.root[0].self_closing?
      assert_equal true, tree.root[0].void?
    end

    test "void elements are nested properly" do
      tree = Tree.new("<div><hr>test</hr></div>")
      assert_equal 1, tree.errors.size
      assert_equal "end of tag for void element: </hr>", tree.errors[0].message

      assert_equal 1, tree.root.size
      div = tree.root[0]
      assert_equal 2, div.size
      assert_equal true, div[0].element?
      assert_equal true, div[1].text?
    end

    test "parser errors are bubbled up" do
      tree = Tree.new("<>")
      assert_equal 1, tree.errors.size
      assert_equal "expected '/' or tag name", tree.errors[0].message
    end
  end
end
