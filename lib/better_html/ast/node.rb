require 'ast'
require_relative 'iterator'

module BetterHtml
  module AST
    class Node < ::AST::Node
      attr_reader :loc

      def descendants(type, &block)
        AST::Iterator.descendants(self, type, &block)
      end
    end
  end
end
