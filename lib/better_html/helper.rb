module BetterHtml::Helper
  def html(args)
    BetterHtml::HtmlNode.new(args)
  end
end
