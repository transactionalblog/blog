#
# BibitemMacro.rb
#
# Copyright (c) Zhang Yang, 2020.
#
# Released under Open Works License, 0.9.2
#

module AsciidoctorBibtex
  # BibitemMacro
  #
  # Class to hold information about a bibitem macro.  A bibtem macro has
  # only text and key
  #
  # This class also provides a class method to extract macros from a line of
  # text.
  #
  class BibitemMacro
    #
    # Grammar for the bibitem macro: bibitem:[key]
    #

    # matches a bibitem key
    BIBITEM_KEY = /[^\s\]]+/.freeze
    # matches the full macro
    BIBITEM_MACRO = /bibitem:(\w*)\[(#{BIBITEM_KEY})\]/.freeze

    # Given a line, return a list of BibitemMacro instances
    def self.extract_macros(line)
      result = []
      full = BIBITEM_MACRO.match line
      while full
        text = full[0]
        arg = full[1]
        key = full[2]
        result << BibitemMacro.new(text, arg, key)
        # look for next citation on line
        full = BIBITEM_MACRO.match full.post_match
      end
      result
    end

    attr_reader :text, :arg, :key

    # Create a BibitemMacro object
    #
    # text: the full macro text matched by BIBITEM_MACRO
    # arg: an optional argument to control behavior
    # key: bibitem key
    def initialize(text, arg, key)
      @text = text
      @arg = arg
      @key = key
    end
  end
end
