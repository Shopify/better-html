require 'better_html/tree/attributes_list'

module BetterHtml
  module Tree
    class Tag
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def loc
        @node.name_parts.first&.location
      end

      def name
        @node&.name&.downcase
      end

      def closing?
        @node.closing?
      end

      def self_closing?
        @node.self_closing?
      end

      def attributes
        @attributes ||= AttributesList.from_nodes(@node.attributes)
      end
    end
  end
end
