module BetterHtml
  module Tree
    class Attribute
      attr_reader :node

      QUOTES_TOKEN_TYPES = [:attribute_quoted_value_start, :attribute_quoted_value_end]
      VALUE_TOKEN_TYPES = [:attribute_quoted_value, :attribute_unquoted_value]

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
        parts = @node.value_parts.reject{ |node| QUOTES_TOKEN_TYPES.include?(node.type) }
        parts.map { |s| VALUE_TOKEN_TYPES.include?(s.type) ? CGI.unescapeHTML(s.text) : s.text }.join
      end
    end
  end
end
