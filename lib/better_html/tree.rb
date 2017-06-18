require 'better_html/node_iterator'

module BetterHtml
  class Tree
    attr_reader :errors
    attr_reader :root

    cattr_accessor :void_elements
    self.void_elements = %w(area base br col embed hr img
      input keygen link menuitem meta param source track wbr)

    def initialize(data, **options)
      @data = data
      @errors = Errors.new
      @nodes = BetterHtml::NodeIterator.new(data, **options.slice(:template_language))
      @root = TreeRoot.new
      construct!
      @nodes.parser_errors&.each do |error|
        @errors.add(error)
      end
    end

    private

    class TreeError < HtmlError
      attr_reader :token

      def initialize(token, message)
        @token = token
        super(message)
      end
    end

    def add_error(token, message)
      @errors.add(TreeError.new(token, message))
    end

    def construct!
      current = @root
      @nodes.each do |node|
        case node.node_type
        when :text, :comment, :cdata
          current << node
        when :element
          if node.closing?
            if void_elements.include?(node.name)
              add_error(node.name_parts.first,
                "end of tag for void element: </#{node.name}>")
            elsif current.root?
              add_error(node.name_parts.first,
                "mismatched </#{node.name}> at root of tree")
            else
              if node.name == current.name
                current.end_node = node
                current = current.parent
              else
                add_error(node.name_parts.first,
                  "mismatched </#{node.name}> in <#{current.name}> element")
              end
            end
          else
            element = Element.new(parent: current, start_node: node)
            current << element
            current = element unless element.closed?
          end
        end
      end
    end

    class NodeContainer
      attr_accessor :content_nodes
      delegate :each, :[], :each_with_index, :<<, :push,
        :size, :empty?, :any?, to: :content_nodes

      def root?
        false
      end

      def initialize
        @content_nodes = []
      end
    end

    class TreeRoot < NodeContainer
      def root?
        true
      end
    end

    class Element < NodeContainer
      attr_reader :parent
      attr_accessor :start_node
      attr_accessor :end_node

      delegate :name, :attributes, :self_closing?, to: :start_node
      delegate :element?, :text?, :comment?, :cdata?, to: :start_node

      def initialize(parent:, start_node:)
        super()
        @parent = parent
        @start_node = start_node
      end

      def closed?
        void? || end_node.present? || self_closing?
      end

      def void?
        BetterHtml::Tree.void_elements.include?(name)
      end
    end
  end
end
