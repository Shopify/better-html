module BetterHtml
  class NodeIterator
    class Base
      def self.tokenized_attribute(name)
        class_eval <<~RUBY
          attr_reader :#{name}_parts

          def #{name}
            #{name}_parts.map(&:text).join
          end
        RUBY
      end
    end
  end
end
