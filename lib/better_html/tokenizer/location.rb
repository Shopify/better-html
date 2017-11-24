module BetterHtml
  module Tokenizer
    class Location
      attr_accessor :start, :stop

      def initialize(document, start, stop, line = nil, column = nil)
        raise ArgumentError, "start location #{start} is out of range for document of size #{document.size}" if start > document.size
        raise ArgumentError, "stop location #{stop} is out of range for document of size #{document.size}" if stop > document.size
        raise ArgumentError, "end of range must be greater than start of range (#{stop} < #{start})" if stop < start

        @document = document
        @start = start
        @stop = stop
        @line = line
        @column = column
      end

      def range
        Range.new(start, stop)
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
        line_content = extract_line(line: line)
        spaces = line_content.scan(/\A\s*/).first
        column_without_spaces = [column - spaces.length, 0].max
        underscore_length = [[stop - start + 1, line_content.length - column_without_spaces].min, 1].max
        "#{line_content.gsub(/\A\s*/, '')}\n#{' ' * column_without_spaces}#{'^' * underscore_length}"
      end

      private

      def calculate_line
        return 1 if start == 0
        @document[0..start-1].scan("\n").count + 1
      end

      def calculate_column
        return 0 if start == 0
        @document[0..start-1]&.split("\n", -1)&.last&.length || 0
      end

      def extract_line(line:)
        @document.split("\n", -1)[line - 1]&.gsub(/\n$/, '') || ""
      end
    end
  end
end
