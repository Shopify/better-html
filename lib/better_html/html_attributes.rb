module BetterHtml
  class HtmlAttributes < Hash
    def initialize(data)
      @data = data.stringify_keys
    end

    def to_s
      @data.map do |k,v|
        unless k =~ /\A[a-z0-9\:\-]+\z/
          raise ArgumentError, "attribute names should contain only lowercase letters, numbers, or :-._ symbols"
        end
        "#{k}=\"#{CGI.escapeHTML(v.to_s)}\""
      end.join(" ")
    end
  end
end
