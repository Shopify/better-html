module BetterHtml
  class NodeIterator
    class Location
      attr_accessor :start, :stop, :line, :column

      def initialize(start, stop, line, column)
        @start = start
        @stop = stop
        @line = line
        @column = column
      end
    end
  end
end
