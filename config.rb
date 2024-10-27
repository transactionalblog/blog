# Activate and configure extensions
# https://middlemanapp.com/advanced/configuration/#configuring-extensions

require_relative 'asciidoc_extensions/string_ext'

activate :autoprefixer do |prefix|
  prefix.browsers = "last 2 versions"
end

require 'asciidoctor-diagram'
require_relative 'asciidoc_extensions/asciidoctor-bibtex'
require_relative 'asciidoc_extensions/inline_macros'
require_relative 'asciidoc_extensions/ophistory_diagram'
require_relative 'asciidoc_extensions/postprocessors'
require_relative 'asciidoc_extensions/reading_time'
activate :asciidoc do |asciidoc|
  asciidoc.backend = 'xhtml5'
  asciidoc.safe = :unsafe
  asciidoc.template_dirs = 'asciidoc_templates'
  asciidoc.attributes = [
    'source-highlighter=rouge',
    'toc-title=',
    'nospace=',
    'hook-preamble=true',
    'table-caption!='
  ]
  asciidoc.promoted_attributes = [
    'draft',
    'updated',
  ]
  asciidoc.promoted_attributes_convert_dashes = true
end
set :skip_build_clean, proc {|f| f.start_with? 'build/images/'}

activate :reading_time

class ImageDirPerAsciidoc < Middleman::Extension
  def initialize(app, options_hash={}, &block)
    super
  end

  def manipulate_resource_list(resources)
    resources.each do |resource|
      if resource.source_file.end_with? '.adoc'
        resource.options[:renderer_options][:attributes]['icons'] = 'font'
        resource.options[:renderer_options][:attributes]['imagesdir'] = ::File.join(@app.config[:asciidoc][:attributes]['imagesdir'].chomp('@'), resource.page_id + "@")
        resource.options[:renderer_options][:attributes]['imagesoutdir'] = ::File.join(@app.config[:asciidoc][:attributes]['site-destination'], @app.config[:images_dir], resource.page_id + "@")
      end
    end

    resources
  end
end

::Middleman::Extensions.register(:imagedir_per_asciidoc, ImageDirPerAsciidoc)
activate :imagedir_per_asciidoc

require 'nokogiri'
activate :blog do |blog|
  blog.sources = "{category}/{title}.html"
  blog.permalink = "{category}/{title}.html"
  blog.default_extension = ".adoc"
  blog.summary_length = nil
  blog.summary_generator = Proc.new { |article, rendered, length, ellipsis|
    if article.data.hook_preamble == false
      next ''
    end
    page_hook = article.data.hook
    if page_hook
      '<div>' + page_hook + '</div>'
    else
      noko = Nokogiri::HTML5(rendered)
      if f = noko.at('#chosen_preamble')
        '<div>' + f.search('p').children.map(&:to_xml).join() + '</div>'
      elsif f = noko.at('#preamble > p:first-of-type')
        '<div>' + f.children.map(&:to_xml).join() + '</div>'
      else
        ''
        #Nokogiri::HTML(rendered).at('body > p')&.to_html
      end
    end
  }
end

# Layouts
# https://middlemanapp.com/basics/layouts/

# Per-page layout changes
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false
page '/*.bib', layout: false

ignore /.*\.swp/

# Helpers
# Methods defined in the helpers block are available in templates
# https://middlemanapp.com/basics/helper-methods/
helpers do
  def join_paths(*paths)
    paths.map { |path| path.delete_prefix('/').chomp('/') }.reject(&:empty?).join('/')
  end

  def add_http_prefix(path)
    '/' + join_paths( config.http_prefix, path )
  end

  def html_to_text(html)
    Nokogiri::HTML(html).text
  end
end

# Build-specific configuration
# https://middlemanapp.com/advanced/configuration/#environment-specific-settings

require 'terser'

config[:domain] = "http://localhost:4567"

configure :ghpages do
  config[:domain] = "https://draft.transactional.blog"
  set :http_prefix, "/"
  activate :minify_css
  activate :minify_javascript, compressor: Terser.new
  activate :asset_hash, :ignore => [
    %r{^images/rss.svg},
    %r{^stylesheets/bamboo/.*.css},
  ]
  import_file File.expand_path("_ghpages_cname", config[:source]), "/CNAME"
end

configure :transactionalblog do
  config[:domain] = "https://transactional.blog"
  set :http_prefix, "/"
  activate :minify_css
  activate :minify_javascript, compressor: Terser.new
  activate :asset_hash, :ignore => [
    %r{^images/rss.svg},
    %r{^stylesheets/bamboo/.*.css},
  ]
end
