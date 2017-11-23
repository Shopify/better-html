require_relative 'base'

module BetterHtml
  class Parser
    class Attribute < Base
      tokenized_attribute :name
      tokenized_attribute :value

      def initialize
        @name_parts = []
        @value_parts = []
      end

      def unescaped_value_parts
        value_parts.map do |part|
          next if ["'", '"'].include?(part.text)
          if [:attribute_quoted_value, :attribute_unquoted_value].include?(part.type)
            CGI.unescapeHTML(part.text)
          else
            part.text
          end
        end.compact
      end

      def unescaped_value
        unescaped_value_parts.join
      end

      def value_without_quotes
        value_parts.map{ |s| ["'", '"'].include?(s.text) ? '' : s.text }.join
      end
    end
  end
end
