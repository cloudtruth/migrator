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
        use_cli(ENV['CT_CLI_OLD_PATH'] || "cloudtruth")
        set_dry_run(@dry_run, %w[set unset delete])

        if cloudtruth(*%w(--version)) !~ /0\.5/
          raise "Import needs cloudtruth cli == 0.5.x"
        end

        json = {}

        logger.info { "Fetching integrations" }
        integrations = JSON.parse(cloudtruth(*%w(integrations list --format json --values)))
        json = json.merge(integrations)

        logger.info { "Fetching environments" }
        environments=JSON.parse(cloudtruth(*%w(environments list --format json --values)))
        json = json.merge(environments)

        logger.info { "Fetching projects" }
        projects=JSON.parse(cloudtruth(*%w(projects list --format json --values)))
        json = json.merge(projects)

        envs = environments['environment'].collect {|e| e['Name'] }
        json['project'].each do |project|
          envs.each do |env|
            project_name = project["Name"]
            logger.info { "Fetching parameters for project='#{project_name}' environment='#{env}'" }

            begin
              params=JSON.parse(cloudtruth(*%W(--project #{project_name} --env #{env} parameters list --format json --values --secrets)))
              params_dynamic=JSON.parse(cloudtruth(*%W(--project #{project_name} --env #{env} parameters list --format json --values --secrets --dynamic)))
              params_dynamic['parameter'].each do |pd|
                found = params['parameter'].find {|p| p['Name'] == pd['Name'] }
                found.merge!(pd) if found
              end
            rescue JSON::ParserError => e
              case e.message
              when /No dynamic parameters/
                logger.info { "No dynamic parameters" }
              when /No parameters found/
                logger.info { "No parameters found" }
                next
              else
                raise
              end
            end

            project['parameter'] ||= {}
            project['parameter'][env] = params['parameter']
          end
        end

        output = JSON.pretty_generate(json)
        if @dry_run
          logger.info { "(DryRun) Skipping write of export data to '#{@data_file}':\n#{output}" }
        else
          logger.info { "Writing export data to '#{@data_file}'" }
          File.write(@data_file, output)
        end
      end

    end

  end
end
