require 'clamp'
require_relative 'export'
require_relative 'import'
require_relative 'runner'

module Cloudtruth
  module Migrator
    class CLI < Clamp::Command

      include GemLogger::LoggerSupport

      banner <<~'EOF'
        Migrates data for cloudtruth refactor
      EOF

      option "--api-key",
             'KEY', "The api key for cloudtruth"

      option "--api-url",
             'URL', "The api url for cloudtruth"

      option "--data-file",
             'FILE', "The data file to export/import to/from",
             default: "export.json"

      subcommand "export", "Export data from old cloudtruth", Export
      subcommand "import", "Import data to new cloudtruth", Import

      option ["-n", "--dry-run"],
             :flag, "Perform a dry run",
             default: false

      option ["-q", "--quiet"],
             :flag, "Suppress output",
             default: false

      option ["-d", "--debug"],
             :flag, "Debug output",
             default: false

      option ["-c", "--[no-]color"],
             :flag, "colorize output (or not)  (default: $stdout.tty?)",
             default: true

      option ["-v", "--version"],
             :flag, "show version",
             default: false

      # hook into clamp lifecycle to force logging setup even when we are calling
      # a subcommand
      def parse(arguments)
        super

        level = :info
        level = :debug if debug?
        level = :error if quiet?
        Cloudtruth::Migrator::Logging.setup_logging(level: level, color: color?)
        data_file # weird, the attr for an option doesn't show up in subcommands unless we call it at least once in the main command
        ENV['CLOUDTRUTH_API_KEY'] = api_key if api_key.present?
        ENV['CLOUDTRUTH_SERVER_URL'] = api_url if api_url.present?
      end

      def execute
        if version?
          logger.info "Cloudtruth Migrator Version #{VERSION}"
          exit(0)
        end
      end

    end
  end

  # Hack to make clamp usage less of a pain to get long lines to fit within a
  # standard terminal width
  class Clamp::Help::Builder

    def word_wrap(text, line_width: 79)
      text.split("\n").collect do |line|
        line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip.split("\n") : line
      end.flatten
    end

    def string
      indent_size = 4
      indent = " " * indent_size
      StringIO.new.tap do |out|
        lines.each do |line|
          case line
            when Array
              if line[0].length > 0
                out << indent
                out.puts(line[0])
              end

              formatted_line = line[1].gsub(/\((default|required)/, "\n\\0")
              word_wrap(formatted_line, line_width: (79 - indent_size * 2)).each do |l|
                out << (indent * 2)
                out.puts(l)
              end
            else
              out.puts(line)
          end
        end
      end.string
    end

  end
end
