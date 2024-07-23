#
# styles.rb
# Simple checks on available styles through CSL
#

require 'citeproc'
require 'csl/styles'

module AsciidoctorBibtex
  module StyleUtils
    def self.available
      CSL::Style.ls
    end

    def self.default_style
      'association-for-computing-machinery'
    end

    def self.valid?(style)
      Styles.available.include? style
    end

    def self.is_numeric?(style)
      false
      #CSL::Style.load(style).citation_format == :numeric
    end
  end
end
