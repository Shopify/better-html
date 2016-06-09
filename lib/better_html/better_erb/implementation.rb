class BetterHtml::BetterErb
  class Implementation < ActionView::Template::Handlers::Erubis
    def add_preamble(src)
      super
      wrap_buffer(src)
    end

    def add_postamble(src)
      #src << "puts '--------------------';\n"
      #src << "puts @output_buffer.to_s;\n"
      #src << "puts '--------------------';\n"
      super
    end

    private

    def wrap_buffer(src)
      class_name = "BetterHtml::BetterErb::ValidatedOutputBuffer"
      src << "@output_buffer = #{class_name}.new(@output_buffer) unless @output_buffer.is_a?(#{class_name});"
    end
  end
end
