require 'metainspector'
require 'nokogiri'
require 'reverse_markdown'
require './rm_converters'
require 'shellwords'


# Removes share buttons and "back to top" div
def remove_unneccesary_divs(page)
  @doc = Nokogiri::HTML::DocumentFragment.parse(page.to_s)
  @doc.css("div.addtoany_share_save_container").remove()
  @doc.css("a.backtotop").remove()
  @doc.css("script").remove()
  @doc.css("comment()").remove()
  return Nokogiri::HTML(@doc.to_html)
end


# Converts youtube embed div to markdown format
def youtube_embed_func(youtube_embed, article_title)
  youtube_embed = youtube_embed.split("src=\"")[1].split("\"")[0]
  youtube_id = youtube_embed.split('/').last
  youtube_embed_md = "\n[![#{article_title}](https://img.youtube.com/vi/#{youtube_id}/0.jpg)](#{youtube_embed} \"#{article_title}\")\n"
  return youtube_embed_md
end


def call_MetaInspector(page_url)
  begin
    sleep 5
    headers = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.1 Safari/605.1.15'}
    page = MetaInspector.new(page_url, headers: headers, connection_timeout: 30, read_timeout: 30, retries: 5)
    redo_counter = 0

    while page.response.status != 200 && redo_counter < 7
      puts "HTTP ERROR #{page.response.status}"
      redo_counter = redo_counter + 1
      sleep 10
      page = MetaInspector.new(page_url, headers: headers, connection_timeout: 30, read_timeout: 30, retries: 5)
    end

    return "ERROR" if redo_counter >= 7
    return page
  rescue MetaInspector::TimeoutError, MetaInspector::RequestError, MetaInspector::ParserError, MetaInspector::NonHtmlError => error
    puts "ERROR RESCUED: #{error.inspect}"
    return "ERROR"
  end
end


def convert_article_to_md(page_url, folder, filename)
  page = call_MetaInspector(page_url)
  return if (page == 'ERROR')
  page_html = remove_unneccesary_divs(page)

  article = page_html.at('article')
  article_title = page.h1.first
  article_md = ReverseMarkdown.convert(article, unknown_tags: :pass_through)

  # Add present article name and url in first line
  article_md_array = article_md.split("\n")
  filename_without_index = filename.split(". ")[1..-1].join(". ")
  article_md_array[0] = (article_md_array[0] + ": [#{filename_without_index}](#{page_url})") if folder != "Book"
  article_md = article_md_array.join("\n")

  # youtube iframe
  # youtube_embed = page_html.css("div.responsive-container").to_s
  # if youtube_embed != ''
    # article_md = article_md + youtube_embed_func(youtube_embed, article_title)
  # end

  # Add \n at the end, if absent
  article_md = article_md + "\n" if article_md[-1] != "\n"

  File.write("#{folder}/#{filename}.md", article_md)
  puts("#{folder}/#{filename}.md")
end


def get_index_url_from_key(key)
  index_urls_hash = {}
  index_urls_hash[:relationships] = "https://www.theschooloflife.com/thebookoflife/category/relationships/?index"
  index_urls_hash[:work] = "https://www.theschooloflife.com/thebookoflife/category/work/?index"
  index_urls_hash[:self_knowledge] = "https://www.theschooloflife.com/thebookoflife/category/self-knowledge/?index"
  index_urls_hash[:sociability] = "https://www.theschooloflife.com/thebookoflife/category/sociability/?index"
  index_urls_hash[:calm] = "https://www.theschooloflife.com/thebookoflife/category/calm/?index"
  index_urls_hash[:leisure] = "https://www.theschooloflife.com/thebookoflife/category/leisure/?index"
  return index_urls_hash[key].to_s
end


def start(index_key)
  Dir.mkdir("Book") unless File.exist?("Book")
  base_url = "https://www.theschooloflife.com/thebookoflife/what-is-the-book-of-life/"
  convert_article_to_md(base_url, "Book", "What is the Book of Life")

  index_url = get_index_url_from_key(index_key)
  index_topic = index_key.to_s.split('_').map(&:capitalize).join(' ')
  puts index_topic

  # 
  index_url_page = call_MetaInspector(index_url)
  return if index_url_page == 'ERROR'

  # check if folder exists, else create one
  folder_path = "Book/" + index_topic
  Dir.mkdir(folder_path) unless File.exist?(folder_path)

  index_page_sections = index_url_page.parsed.css("div.category-posts/section")
  index_page_sections.each do |section|
    section_category = section.css("div.category_title").text
    puts section_category
    folder_sub_path = folder_path + "/" + section_category.to_s.gsub('/','-')
    Dir.mkdir(folder_sub_path) unless File.exist?(folder_sub_path)

    section.css("ul/li").each do |article|
      filename = article.text.split.join(' ').gsub('/','-')
      article_url = article.at_css("a")['href']
      convert_article_to_md(article_url, folder_sub_path, filename)
    end

    # delete duplicate files
    `fdupes --reverse --delete --noprompt #{folder_sub_path.shellescape}`

  end
end

# Argument(s) from command line
ARGV.each do|index_key|
  start(index_key.to_sym)
end
