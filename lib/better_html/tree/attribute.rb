module BetterHtml
  module Tree
    class Attribute
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

      def value
        parts = @node.value_parts.reject{ |node| ["'", '"'].include?(node.text) }
        parts.map { |s| [:attribute_quoted_value, :attribute_unquoted_value].include?(s.type) ? CGI.unescapeHTML(s.text) : s.text  }.join
      end
    end
  end
end
