require_relative 'base'

module BetterHtml
  class NodeIterator
    class ContentNode < Base
      tokenized_attribute :content

      def initialize
        @content_parts = []
      end
    end
  end
end
