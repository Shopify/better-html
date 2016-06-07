require 'html_tokenizer'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/output_safety'

class BetterHtml::HtmlNode
  def initialize(template)
    @template = template
  end

  def format(args)
    args = args.symbolize_keys
    fmt = Formatter.new(@template)
    fmt.format_identifier do |parser, identifier|
      format_identifier(args, parser, identifier.to_sym)
    end
    self.class.new(fmt.to_s)
  end
  alias :% :format

  def to_s
    @template
  end

  private

  def format_identifier(args, parser, identifier)
    if parser.context == :attribute_value
      ERB::Util.html_escape_once(args.fetch(identifier))
    else
      args.fetch(identifier)
    end
  end

  class Formatter
    def initialize(template)
      @template = template
      @output = String.new
      @format_identifier = nil
    end

    def format_identifier(&block)
      @format_identifier = block
    end

    def to_s
      parser = HtmlTokenizer::Parser.new
      scan_template do |name, str|
        if name == :text
          @output << str
          parser.parse(str)
        elsif name == :identifier
          @output << @format_identifier.call(parser, str).to_s
        end
      end
      @output
    end

    def scan_template
      marker_start = nil
      scanner = BetterHtml::StringScanner.new
      scanner.scan(@template) do |name, start, stop|
        if name == :text
          yield :text, @template[start...stop]
        elsif name == :percent
          yield :text, "%"
        elsif name == :marker_start
          marker_start = start
        elsif name == :identifier
          yield :identifier, @template[start...stop]
        elsif name == :marker_end
          marker_start = nil
        else
          raise "Unknown scanner part name: #{name.inspect}"
        end
      end

      if marker_start
        raise "Unclosed marker at position #{marker_start}: #{@template[marker_start..@template.size]}"
      end
    end
  end
end
