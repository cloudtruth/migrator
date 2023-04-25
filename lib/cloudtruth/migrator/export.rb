require 'json'
require 'pp'
require_relative 'runner'

module Cloudtruth
  module Migrator

    class Export < Clamp::Command
      include GemLogger::LoggerSupport
      include Runner

      def execute
        logger.debug { self }
        use_cli(ENV['CT_CLI_EXPORT_BINARY'] || "cloudtruth")
        set_dry_run(@dry_run, %w[set unset delete])
        set_data_file(@data_file)
        set_continue_on_failure(@continue_on_failure)

        json = {}

        logger.info { "Performing backup snapshot" }
        json = JSON.parse(cloudtruth(*%w(backup snapshot --yes --format json)))

        logger.info { "Fetching integrations" }
        json['integrations'] = cloudtruth(*%w(integrations list --format json --values), json_key: 'integration')

        output = JSON.pretty_generate(json)
        if @dry_run
          logger.info { "(DryRun) Skipping write of export data to '#{@data_file}':\n#{output}" }
        else
          logger.info { "Writing export data to '#{@data_file}'" }
          File.write(@data_file, output)
        end

        logger.info { "Export complete" }
      end

    end

  end
end
