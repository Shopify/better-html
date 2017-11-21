module BetterHtml
  class Parser
    class Base
      def self.tokenized_attribute(name)
        class_eval <<~RUBY
          attr_reader :#{name}_parts

          def #{name}
            #{name}_parts.map(&:text).join
          end
        RUBY
      end

      def node_type
        self.class.name.split('::').last.downcase.to_sym
      end

      %w(text cdata comment element).each do |name|
        class_eval <<~RUBY
          def #{name}?
            node_type == :#{name}
          end
        RUBY
      end
    end
  end
end
