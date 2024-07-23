#
# PathUtils.rb
#
# High-level utilities for files.
#

module AsciidoctorBibtex
  module PathUtils
    # Locate a bibtex file to read in given dir
    def self.find_bibfile(filename, dir)
      candidates = Dir.glob("#{dir}/#{filename}")
      if candidates.empty?
        return ''
      else
        return candidates.first
      end
    rescue StandardError # catch all errors, and return empty string
      ''
    end

    def self.resolve_bibfile(bibtex_file, document)
      return bibtex_file if File.file? bibtex_file

      candidate = self.find_bibfile(bibtex_file, document.base_dir)
      return candidate if File.file? candidate
      
      candidate = self.find_bibfile(bibtex_file, 'source')
      return candidate if File.file? candidate

      STDERR.puts 'Error: bibtex-file is not set and automatic search failed'
      exit
    end
  end
end
