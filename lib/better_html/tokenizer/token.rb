module BetterHtml
  module Tokenizer
    class Token
      attr_reader :type, :location, :code_location, :self_closing

      def initialize(type:, location:, code_location: nil, self_closing: nil)
        @type = type
        @location = location
        @code_location = code_location
        @self_closing = self_closing
      end

      def code
        code_location&.source
      end

      def text
        location&.source
      end
    end
  end
end
