require 'nokogiri'

class ReadingTime < Middleman::Extension
    def initialize(app, options_hash={}, &block)
        super
    end

    helpers do
        def reading_time(article)
            # Medium uses 265, but it looks like the reading speed for technical material is around 150?
            # Let's just say 200 then?
            words_per_minute = 200

            html = Nokogiri::HTML5(article.body)

            html.at('div.bibliography')&.remove
            html.at('div.toc')&.remove
            html.css('table').remove
            html.css('script').remove

            words = html.text.split.size
            minutes = (words.to_f / words_per_minute).floor
            "#{minutes}"
        end
    end
end

::Middleman::Extensions.register(:reading_time, ReadingTime)