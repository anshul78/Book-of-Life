module ReverseMarkdown
  module Converters

    class IFrame < Base
      def convert(node, state = {})
        alt = node['alt'] || ""
        src = node['src']
        title = extract_title(node)

        if src.include?("youtube.com/embed")
          src_id = src.split('/').last.split("?").first
          "[![#{alt}](https://img.youtube.com/vi/#{src_id}/0.jpg)](#{src} '#{title}')"
        else
          treat_children(node, state)
        end

      end
    end

    # class Figure < Base
    #   def convert(node, state = {})
    #     content = treat_children(node, state)
    #     content
    #   end
    # end

    register :iframe, IFrame.new
    # register :figure, Figure.new

  end
end

