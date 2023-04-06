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
        set_continue_on_failure(@continue_on_failure)

        json = {}

        logger.info { "Fetching integrations" }
        json['integration'] = cloudtruth(*%w(integrations list --format json --values), json_key: 'integration')

        logger.info { "Fetching environments" }
        json['environment'] = cloudtruth(*%w(environments list --format json --values), json_key: 'environment')

        logger.info { "Fetching projects" }
        json['project'] = cloudtruth(*%w(projects list --format json --values), json_key: 'project')

        envs = json['environment'].collect {|e| e['Name'] }
        json['project'].each do |project|
          envs.each do |env|
            project_name = project["Name"]
            logger.info { "Fetching parameters for project='#{project_name}' environment='#{env}'" }

            params = cloudtruth(*%W(--project #{project_name} --env #{env} parameters list --immediate_parameters --format json --values --secrets), json_key: 'parameter', allow_empty: true)
            next if params.nil?

            params_dynamic = cloudtruth(*%W(--project #{project_name} --env #{env} parameters list --immediate_parameters --format json --values --secrets --dynamic), json_key: 'parameter', allow_empty: true)
            Array(params_dynamic).each do |pd|
              found = params.find {|p| p['Name'] == pd['Name'] }
              found.merge!(pd) if found
            end

            params_evaluated = cloudtruth(*%W(--project #{project_name} --env #{env} parameters list --immediate_parameters --format json --values --secrets --evaluated), json_key: 'parameter', allow_empty: true)
            Array(params_evaluated).each do |pe|
              found = params.find {|p| p['Name'] == pe['Name'] }
              found.merge!(pe) if found
            end

            project['parameter'] ||= {}
            project['parameter'][env] = params
          end
        end

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
