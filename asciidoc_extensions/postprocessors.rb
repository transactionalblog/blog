# From https://github.com/asciidoctor/asciidoctor/issues/1060#issuecomment-52010870
require 'asciidoctor'
require 'asciidoctor/extensions'

include ::Asciidoctor

class UndoReplacements < Extensions::Postprocessor
  Replacements = {
    "&#8594;" => "->",
    "&#8658;" => "=>",
    "&#8656;" => "<=",
    "&#8592;" => "<-",
  }

  def process document, output
    re = Regexp.new(Replacements.keys.map { |x| Regexp.escape(x) }.join('|'))
    output.gsub(re) { |m| Replacements[m] }
  end
end

Extensions.register :undo do |document|
    document.postprocessor UndoReplacements
end
