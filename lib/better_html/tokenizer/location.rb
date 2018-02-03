module BetterHtml
  module Tokenizer
    class Location
      attr_accessor :document, :start, :stop
      alias_method :begin_pos, :start

      def initialize(document, start, stop)
        raise ArgumentError, "start location #{start} is out of range for document of size #{document.size}" if start > document.size
        raise ArgumentError, "stop location #{stop} is out of range for document of size #{document.size}" if stop > document.size
        raise ArgumentError, "end of range must be greater than start of range (#{stop} < #{start})" if stop < start

        @document = document
        @start = start
        @stop = stop
      end

      def range
        Range.new(begin_pos, end_pos, true)
      end

      def line_range
        Range.new(start_line, stop_line)
      end

      def end_pos
        stop + 1
      end

      def size
        stop - start
      end

      def source
        @document[range]
      end

      def start_line
        @start_line ||= calculate_line(start)
      end

      def line
        start_line
      end

      def stop_line
        @stop_line ||= calculate_line(stop)
      end

      def start_column
        @start_column ||= calculate_column(start)
      end

      def column
        start_column
      end

      def stop_column
        @stop_column ||= calculate_column(stop)
      end

      def line_source_with_underline
        line_content = extract_line(line: start_line)
        spaces = line_content.scan(/\A\s*/).first
        column_without_spaces = [column - spaces.length, 0].max
        underscore_length = [[stop - start + 1, line_content.length - column_without_spaces].min, 1].max
        "#{line_content.gsub(/\A\s*/, '')}\n#{' ' * column_without_spaces}#{'^' * underscore_length}"
      end

      private

      def calculate_line(pos)
        return 1 if pos == 0
        @document[0..pos-1].scan("\n").count + 1
      end

      def calculate_column(pos)
        return 0 if pos == 0
        @document[0..pos-1]&.split("\n", -1)&.last&.length || 0
      end

      def extract_line(line:)
        @document.split("\n", -1)[line - 1]&.gsub(/\n$/, '') || ""
      end
    end
  end
end
