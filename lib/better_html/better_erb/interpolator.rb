module BetterHtml
  class BetterErb
    class Interpolator
      def initialize(parser)
        @parser = parser
      end

      def to_safe_value(value, identifier, auto_escape)

        if @parser.context == :attribute_value
          unless @parser.attribute_quoted?
            raise DontInterpolateHere, "Do not interpolate without quotes around this "\
              "attribute value. Instead of "\
              "<#{@parser.tag_name} #{@parser.attribute_name}=#{@parser.attribute_value}#{identifier}> "\
              "try <#{@parser.tag_name} #{@parser.attribute_name}=\"#{@parser.attribute_value}#{identifier}\">."
          end

          # in a <tag attr="...here..."> we always escape
          CGI.escapeHTML(value.to_s)

        elsif @parser.context == :attribute
                # in a <tag attr=...here...> we always escape and add quotes
          '"' + CGI.escapeHTML(value.to_s) + '"'

        elsif @parser.context == :tag
          # FIXME: in a <tag ...here...> we never allow interpolation
          #raise DontInterpolateHere, "Do not interpolate in a tag. "\
          #  "Instead of <#{@parser.tag_name} #{identifier}> please "\
          #  "try <#{@parser.tag_name} name=#{identifier}>."

        elsif @parser.context == :tag_name
          if value.include?('/') || value.include?(' ')
            raise UnsafeHtmlError, "Detected / or whitespace interpolated in a "\
              "tag name around: <#{@parser.tag_name}#{identifier}."
          end

          value = value.to_s
          unless value =~ /\A[a-z0-9\:\-]+\z/
            raise UnsafeHtmlError, "Detected invalid characters as part of the interpolation "\
              "into a tag name around: <#{@parser.tag_name}#{identifier}."
          end

          value
        elsif @parser.context == :rawtext

          # in a <script> or something we never interpolate
          value.to_s
        elsif @parser.context == :none
          if value.is_a?(ValidatedOutputBuffer)
            # in html context, never escape a ValidatedOutputBuffer
            value.to_s
          else
            # in html context, follow auto_escape rule
            if auto_escape
              auto_escape_interpolated_argument(value)
            else
              value.to_s
            end
          end
        else
          raise InterpolatorError, "Tried to interpolated into unknown location #{@parser.context}."
        end
      end

      private

      def auto_escape_interpolated_argument(arg)
        arg.html_safe? ? arg.to_s : CGI.escapeHTML(arg.to_s)
      end
    end
  end
end
