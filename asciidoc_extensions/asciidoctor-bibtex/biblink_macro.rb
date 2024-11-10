module AsciidoctorBibtex
  # BiblinkMacro
  #
  # Class to hold information about a biblink macro.  A biblink macro has
  # only text and key
  #
  # This class also provides a class method to extract macros from a line of
  # text.
  #
  class BiblinkMacro
    #
    # Grammar for the biblink macro: biblink:[key]
    #

    # matches a biblink key
    BIBLINK_KEY = /[^\s\]]+/.freeze
    # matches the full macro
    BIBLINK_MACRO = /biblink:(\w*)\[(#{BIBLINK_KEY})\]/.freeze

    # Given a line, return a list of BiblinkMacro instances
    def self.extract_macros(line)
      result = []
      full = BIBLINK_MACRO.match line
      while full
        text = full[0]
        arg = full[1]
        key = full[2]
        result << BiblinkMacro.new(text, arg, key)
        # look for next citation on line
        full = BIBLINK_MACRO.match full.post_match
      end
      result
    end

    attr_reader :text, :arg, :key

    # Create a BiblinkMacro object
    #
    # text: the full macro text matched by BIBLINK_MACRO
    # arg: an optional argument to control behavior
    # key: biblink key
    def initialize(text, arg, key)
      @text = text
      @arg = arg
      @key = key
    end
  end
end
