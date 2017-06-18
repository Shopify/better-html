module BetterHtml
  module TestHelper
    module SafetyTesterBase

      class SafetyError < InterpolatorError
        attr_reader :node, :token

        def initialize(node, token, message)
          @node = node
          @token = token
          super(message)
        end
      end

      private

      def format_safety_error(data, error)
        loc = error.token.location
        s = "On line #{loc.line}\n"
        s << "#{error.message}\n"
        line = extract_line(data, loc.line)
        s << "#{line}\n"
        length = [[loc.stop - loc.start, line.length - loc.column].min, 1].max
        s << "#{' ' * loc.column}#{'^' * length}\n\n"
        s
      end

      def extract_line(data, line)
        line = data.lines[line-1]
        line.nil? ? "" : line.gsub(/\n$/, '')
      end

    end
  end
end
