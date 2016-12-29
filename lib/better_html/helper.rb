module BetterHtml::Helper
  def html(args)
    BetterHtml::HtmlNode.new(args)
  end

  def html_attributes(args)
    BetterHtml::HtmlAttributes.new(args)
  end
end
