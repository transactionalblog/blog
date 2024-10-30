require 'asciidoctor/extensions'
require 'asciidoctor-diagram/diagram_processor'
require 'asciidoctor-diagram/diagram_converter'
require 'asciidoctor-diagram/util/cli'
require 'asciidoctor-diagram/util/cli_generator'
require 'asciidoctor-diagram/util/platform'

module Asciidoctor
  module Diagram

    class DbDiagConverter
      include DiagramConverter
      include CliGenerator

      def supported_formats
        [:svg]
      end

      def collect_options(source)
        options = source.attr('options', '').split(',')

        {}
      end

      def command_name()
        raise NotImplementedError
      end

      def convert(source, format, options)
        generate_file(source.find_command(command_name()), 'txt', format.to_s, source.to_s) do |tool_path, input_path, output_path|
          args = [tool_path, "--embed", Platform.native_path(input_path), "-o#{Platform.native_path(output_path)}"]

          args
        end

      end
    end

    class DbDiagSpansConverter < DbDiagConverter
      def command_name()
        'dbdiag-spans'
      end
    end

    class DbDiagSpansBlockProcessor < DiagramBlockProcessor
      use_converter DbDiagSpansConverter
    end

    class DbDiagSpansBlockMacroProcessor < DiagramBlockMacroProcessor
      use_converter DbDiagSpansConverter
    end

    class DbDiagSpansInlineMacroProcessor < DiagramInlineMacroProcessor
      use_converter DbDiagSpansConverter
    end

  end
end

Asciidoctor::Extensions.register do
  block Asciidoctor::Diagram::DbDiagSpansBlockProcessor, :"dbdiag-spans"
  block_macro Asciidoctor::Diagram::DbDiagSpansBlockMacroProcessor, :"dbdiag-spans"
  inline_macro Asciidoctor::Diagram::DbDiagSpansInlineMacroProcessor, :"dbdiag-spans"
end
