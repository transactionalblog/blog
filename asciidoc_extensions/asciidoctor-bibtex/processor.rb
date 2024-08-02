#
# Manage the current set of citations, the document settings,
# and main operations.
#

require 'bibtex'
require 'bibtex/filters'
require 'citeproc'
require 'csl/styles'
require 'set'

require_relative 'citation_macro'
require_relative 'citation_utils'
require_relative 'bibitem_macro'
require_relative 'string_utils'
require_relative 'style_utils'

module AsciidoctorBibtex
  # Class used through utility method to hold data about citations for
  # current document, and run the different steps to add the citations
  # and bibliography
  class Processor
    def initialize(bibfile, links = false, style = 'ieee', locale = 'en-US',
                   numeric_in_appearance_order = false,
                   throw_on_unknown = false, custom_citation_template: '[$id]')
      raise "File '#{bibfile}' is not found" unless FileTest.file? bibfile

      bibtex = BibTeX.open bibfile
      @biblio = bibtex
      @links = links
      @numeric_in_appearance_order = numeric_in_appearance_order
      @style = style
      @locale = locale
      @citations = []
      @filenames = Set.new
      @throw_on_unknown = throw_on_unknown
      @bibtex_ob = '['
      @bibtex_cb = ']'
      match = custom_citation_template.match(/^(.+?)\$id(.+)$/)
      unless match.nil?
        @bibtex_ob = match[1]
        @bibtex_cb = match[2]
      end

      @citeproc = CiteProc::Processor.new style: @style, format: :html, locale: @locale
      @citeproc.import @biblio.to_citeproc
    end

    # Scan a line and process citation macros.
    #
    # As this function being called iteratively on the lines of the document,
    # processor will build a list of all citation keys in the same order as they
    # appear in the original document.
    def process_citation_macros(line)
      CitationMacro.extract_macros(line).each do |citation|
        @citations += citation.items.collect(&:key)
      end
    end

    # Finalize citation macro processing and build internal citation list.
    #
    # As this function being called, processor will clean up the list of
    # citation keys to form a correct ordered citation list.
    def finalize_macro_processing
      @citations = @citations.uniq(&:to_s) # only keep the first occurance
      return if @numeric_in_appearance_order

      @citations = @citations.sort_by do |ref|
        bibitem = @biblio[ref]
        if bibitem.nil?
          [ref]
        else
          # extract the reference, and uppercase.
          # Remove { } from grouped names for sorting.
          author = bibitem.author
          author = bibitem.editor if author.nil?
          year = bibitem.year
          sortable = CitationUtils.author_chicago(author).map { |s| s.upcase.delete '{}' }
          sortable << year if year
          sortable
        end
      end
      nil
    end

    # Replace citation macros with corresponding citation texts.
    #
    # Return new text with all macros replaced.
    def replace_citation_macros(line)
      CitationMacro.extract_macros(line).each do |citation|
        line = line.gsub(citation.text, build_citation_text(citation))
      end
      line
    end

    # Replace bibitem macros with rendered bibitem.
    #
    # Return new text with all macros replaced.
    def replace_bibitem_macros(line)
      BibitemMacro.extract_macros(line).each do |item|
        line = line.gsub(item.text, build_bibitem_text(item.key))
      end
      line
    end

    # Build the bibliography list just as bibtex.
    #
    # Return an array of texts representing an asciidoc list.
    def build_bibliography_list
      result = []
      @citations.each_with_index do |ref, index|
        result << '- ' + build_bibliography_item(ref, index)
      end
      result
    end

    #
    # Internal functions
    #

    # Build the asciidoc text for a single bibliography item
    def build_bibitem_text(key)
      begin
        if @biblio[key].nil?
          puts "Unknown reference: #{key}"
          cptext = key
        else
          cptext = @citeproc.render :bibliography, id: key
          cptext = cptext.first
        end
      rescue Exception => e
        puts "Failed to render #{key}: #{e}"
        cptext = key
      end
      result = StringUtils.html_to_asciidoc(cptext)

      if @biblio[key]&.has_field? 'note'
        result << " #{@biblio[key].note}."
      end

      if @biblio[key]&.has_field? 'scholarcluster'
        result << " https://scholar.google.com/scholar?cluster=#{@biblio[key].scholarcluster}[[scholar\\]]"
      end

      if @biblio[key]&.has_field? 'arxiv'
        result << " https://arxiv.org/abs/#{@biblio[key].arxiv}[[arXiv\\]]"
      end

      result
    end

    # Build bibliography text for a given reference
    def build_bibliography_item(key, index = 0)
      index += 1
      result = ''

      begin
        cptext = if @biblio[key].nil?
                   nil
                 else
                   @citeproc.render :bibliography, id: key
                 end
      rescue Exception => e
        puts "Failed to render #{key}: #{e}"
      end

      result << "[[#{key}]]" if @links
      if StyleUtils.is_numeric? @style
        result << "#{@bibtex_ob}#{index}#{@bibtex_cb} "
      elsif @biblio[key].has_field? 'refname'
        result << "#{@bibtex_ob}#{@biblio[key].refname.to_s}#{@bibtex_cb} "
      else
        result << "#{@bibtex_ob}#{key}#{@bibtex_cb} "
      end
      if cptext.nil?
        return result + key
      else
        result << cptext.first
      end

      if @biblio[key].has_field? 'note'
        result << " #{@biblio[key].note}."
      end

      if @biblio[key].has_field? 'scholarcluster'
        result << " https://scholar.google.com/scholar?cluster=#{@biblio[key].scholarcluster}[[scholar\\]]"
      end

      if @biblio[key].has_field? 'arxiv'
        result << " https://arxiv.org/abs/#{@biblio[key].arxiv}[[arXiv\\]]"
      end

      StringUtils.html_to_asciidoc(result)
    end

    # Build the complete citation text for given citation macro
    def build_citation_text(macro)
      result = ''
      if StyleUtils.is_numeric? @style
        ob = "+#{@bibtex_ob}+"
        cb = "+#{@bibtex_cb}+"
        separator = ','
      elsif macro.type == 'citep'
        ob = '('
        cb = ')'
        separator = ';'
      else
        ob = ''
        cb = ''
        separator = ';'
      end

      macro.items.each_with_index do |cite, index|
        # before all items apart from the first, insert appropriate separator
        result << "#{separator} " unless index.zero?

        # @links requires adding hyperlink to reference
        result << "<<#{cite.key}," if @links

        # if found, insert reference information
        if @biblio[cite.key].nil?
          if @throw_on_unknown
            raise "Unknown reference: #{cite.key}"
          else
            puts "Unknown reference: #{cite.key}"
            cite_text = cite.key.to_s
          end
        else
          cite_text = citation_text(macro, cite)
        end

        result << StringUtils.html_to_asciidoc(cite_text)
        result << '>>' if @links
      end

      if StyleUtils.is_numeric?(@style) && !@links
        result = StringUtils.combine_consecutive_numbers(result)
      end

      #"[.citation]\##{include_pretext(result, macro, ob, cb)}\#"
      "#{include_pretext(result, macro, ob, cb)}"
    end

    # Format locator with pp/p as appropriate
    def format_locator(cite)
      result = ''
      unless cite.locator.empty?
        result << ',' unless StyleUtils.is_numeric? @style
        result << ' '
        # use p.x for single numerical page and pp.x for all others. This will
        # produce pp. 1 seq for complex locators, which is the correct behavior.
        result << if @style.include? 'chicago'
                    cite.locator
                  elsif /^\d+$/ =~ cite.locator
                    "p.&#160;#{cite.locator}"
                  else
                    "pp.&#160;#{cite.locator}"
                  end
      end

      result
    end

    def include_pretext(result, macro, ob, cb)
      pretext = macro.pretext
      pretext += ' ' unless pretext.empty? # add space after any content

      if StyleUtils.is_numeric? @style
        "#{pretext}#{ob}#{result}#{cb}"
      elsif macro.type == 'cite'
        "#{ob}#{pretext}#{result}#{cb}"
      else
        "#{pretext}#{result}"
      end
    end

    # Generate a raw citation text for a single citation item
    def citation_text(macro, cite)
      if StyleUtils.is_numeric? @style
        cite_text = (@citations.index(cite.key) + 1).to_s
        cite_text << format_locator(cite)
      else
        # We generate the citation without locator using citeproc, then strip
        # the surrounding braces, finally add the locator and add braces for
        # `citenp`.
        if @biblio[cite.key].has_field? 'refname'
          cite_text = "[#{@biblio[cite.key].refname.to_s}]"
        else
          cite_text = @citeproc.render :citation, id: cite.key
          cite_text = cite_text.sub('(', '')
          cite_text = cite_text.sub(')', '')
        end
        cite_text += format_locator(cite)
        #year = @biblio[cite.key].year
        #if !year.nil? && macro.type == 'citenp'
        #  segs = cite_text.partition(year.to_s)
        #  head = segs[0].gsub(', ', ' ')
        #  tail = segs[1..-1].join
        #  cite_text = "#{head}(#{tail})"
        #end
        # finally escape some special chars
        cite_text = cite_text.gsub(',', '&#44;') if @links # replace comma
      end

      cite_text
    end
  end
end
