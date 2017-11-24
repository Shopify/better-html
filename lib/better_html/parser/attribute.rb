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
    end
  end
end
