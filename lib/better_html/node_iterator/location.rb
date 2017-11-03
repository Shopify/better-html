module BetterHtml
  class NodeIterator
    class Location
      attr_accessor :start, :stop

      def initialize(document, start, stop, line = nil, column = nil)
        @document = document
        @start = start
        @stop = stop
        @line = line
        @column = column
      end

      def range
        Range.new(start, stop-1)
      end

      def source
        @document[range]
      end

      def line
        @line ||= calculate_line
      end

      def column
        @column ||= calculate_column
      end

      def line_source_with_underline
        line_content = @document.lines[line-1]
        line_content = line_content.nil? ? "" : line_content.gsub(/\n$/, '')
        spaces = line_content.scan(/\A\s*/).first
        column_without_spaces = column - spaces.length
        underscore_length = [[stop - start, line_content.length - column_without_spaces].min, 1].max
        "#{line_content.gsub(/\A\s*/, '')}\n#{' ' * column_without_spaces}#{'^' * underscore_length}"
      end

      private

      def calculate_line
        @document[0..start-1].scan("\n").count + 1
      end

      def calculate_column
        @document[0..start-1]&.split("\n", -1)&.last&.length || 0
      end
    end
  end
end
