require_relative 'base'

module BetterHtml
  class NodeIterator
    class Element < Base
      tokenized_attribute :name
      attr_reader :attributes
      attr_accessor :closing

      def initialize
        @name_parts = []
        @attributes = []
      end

      def closing?
        closing
      end

      def find_attr(wanted)
        @attributes.each do |attribute|
          return attribute if attribute.name == wanted
        end
        nil
      end
      alias_method :[], :find_attr
    end
  end
end
