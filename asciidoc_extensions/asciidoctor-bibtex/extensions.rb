#
# Treeprocessor extension for asciidoctor
#

require 'asciidoctor'
require 'asciidoctor/extensions'
require 'asciidoctor/reader'
require 'asciidoctor/parser'

require_relative 'path_utils'
require_relative 'processor'

module AsciidoctorBibtex
  module Asciidoctor
    # Placeholder paragraph for the bibliography paragraph. Choose a uuid so
    # that it is a special word unlikely to conflict with normal texts.
    BibliographyBlockMacroPlaceholder = %(a5d42deb-3cfc-4293-b96a-fcb47316ce56)

    # BibliographyBlockMacro
    #
    # The `bibliography::[] block macro` processor.
    #
    # This macro processor does only half the work. It just parse the macro
    # and set bibtex file and style if found in the macro. The macro is then
    # expanded to a special paragraph, which is then replaced with generated
    # references by the treeprocessor.
    #
    class BibliographyBlockMacro < ::Asciidoctor::Extensions::BlockMacroProcessor
      use_dsl
      named :bibliography
      name_positional_attributes :style, :locale

      def process(parent, target, attrs)
        # NOTE: bibtex-file and bibtex-style set by this macro shall be
        # overridable by document attributes and command line arguments. So we
        # respect the convention here.
        if target && (!parent.document.attr? 'bibtex-file')
          parent.document.set_attribute 'bibtex-file', target
        end
        if attrs.key?(:style) && (!parent.document.attr? 'bibtex-style')
          parent.document.set_attribute 'bibtex-style', attrs[:style]
        end
        if attrs.key?(:locale) && (!parent.document.attr? 'bibtex-locale')
          parent.document.set_attribute 'bibtex-locale', attrs[:locale]
        end
        create_paragraph parent, BibliographyBlockMacroPlaceholder, {}
      end
    end

    # CitationProcessor
    #
    # A tree processor to replace all citations and bibliography.
    #
    # This processor scans the document, generates a list of citations, replaces
    # each citation with citation text and the reference block macro placeholder
    # with the final bibliography list. It relies on the block macro processor to
    # generate the place holder.
    #
    # NOTE: According to the asiidoctor extension policy, the tree processor can
    # only produce texts with inline macros.
    #
    class CitationProcessor < ::Asciidoctor::Extensions::Treeprocessor
      def process(document)
        if !document.attr? 'bibtex-file'
          return
        end

        bibtex_file = (document.attr 'bibtex-file').to_s
        bibtex_style = ((document.attr 'bibtex-style') || AsciidoctorBibtex::StyleUtils.default_style).to_s
        bibtex_locale = ((document.attr 'bibtex-locale') || 'en-US').to_s
        bibtex_order = ((document.attr 'bibtex-order') || 'appearance').to_sym
        bibtex_throw = ((document.attr 'bibtex-throw') || 'true').to_s.downcase
        bibtex_citation_template = ((document.attr 'bibtex-citation-template') || '[$id]').to_s

        # Fild bibtex file automatically if not supplied.
        bibtex_file = AsciidoctorBibtex::PathUtils.resolve_bibfile(bibtex_file, document)

        # Extract all AST nodes that can contain citations.
        prose_blocks = document.find_by traverse_documents: true do |b|
          (b.content_model == :simple) ||
            (b.context == :list_item) ||
            (b.context == :table_cell) ||
            (b.title?)
        end
        return nil if prose_blocks.nil?

        processor = Processor.new bibtex_file, true, bibtex_style, bibtex_locale,
                                  bibtex_order == :appearance, bibtex_throw == 'true',
                                  custom_citation_template: bibtex_citation_template

        # First pass: extract all citations.
        prose_blocks.each do |block|
          if block.context == :list_item || block.context == :table_cell
            # NOTE: we access the instance variable @text for raw text.
            # Otherwise the footnotes in the text will be pre-processed and
            # ghost footnotes will be inserted (as of asciidoctor 2.0.10).
            line = block.instance_variable_get(:@text)
            unless line.nil? || line.empty?
              processor.process_citation_macros line
            end
          elsif block.content_model == :simple
            block.lines.each do |line|
              processor.process_citation_macros line
            end
          else
            line = block.instance_variable_get(:@title)
            processor.process_citation_macros line
          end
        end
        # Make processor finalize macro processing as required.
        processor.finalize_macro_processing

        # Second pass: replace citations with citation texts.
        prose_blocks.each do |block|
          if block.context == :list_item || block.context == :table_cell
            # NOTE: we access the instance variable @text for raw text.
            line = block.instance_variable_get(:@text)
            unless line.nil? or line.empty?
              line_orig = line
              line = processor.replace_citation_macros(line)
              line = processor.replace_bibitem_macros(line)
              block.text = line if line != line_orig
            end
          elsif block.content_model == :simple
            block.lines.each_with_index do |line, index|
              line_orig = line
              line = processor.replace_citation_macros(line)
              line = processor.replace_bibitem_macros(line)
              block.lines[index] = line if line != line_orig
            end
          else
            # NOTE: we access the instance variable @text for raw text.
            line = block.instance_variable_get(:@title)
            line_orig = line
            line = processor.replace_citation_macros(line)
            line = processor.replace_bibitem_macros(line)
            block.title = line if line != line_orig
          end
        end

        references_asciidoc = processor.build_bibliography_list

        # Third pass: replace the bibliography paragraph with the bibliography
        # list.
        biblio_blocks = document.find_by traverse_documents: true do |b|
          # for fast search (since most searches shall fail)
          (b.content_model == :simple) && (b.lines.size == 1) \
            && (b.lines[0] == BibliographyBlockMacroPlaceholder)
        end
        biblio_blocks.each do |block|
          block_index = block.parent.blocks.index do |b|
            b == block
          end
          reference_blocks = parse_asciidoc block.parent, references_asciidoc
          reference_blocks.reverse.each do |b|
            block.parent.blocks.insert block_index, b
          end
          block.parent.blocks.delete_at block_index + reference_blocks.size
        end

        nil
      end

      # This is an adapted version of Asciidoctor::Extension::parse_content,
      # where resultant blocks are returned as a list instead of attached to
      # the parent.
      def parse_asciidoc(parent, content, attributes = {})
        result = []
        reader = ::Asciidoctor::Reader.new content
        while reader.has_more_lines?
          block = ::Asciidoctor::Parser.next_block reader, parent, attributes
          result << block if block
        end
        result
      end
    end
  end
end

# Register the extensions to asciidoctor
Asciidoctor::Extensions.register do
  block_macro AsciidoctorBibtex::Asciidoctor::BibliographyBlockMacro
  treeprocessor AsciidoctorBibtex::Asciidoctor::CitationProcessor
end
