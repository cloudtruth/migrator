require 'json'
require 'pp'
require_relative 'runner'

module Cloudtruth
  module Migrator

    class Import < Clamp::Command
      include GemLogger::LoggerSupport
      include Runner

      # AWS::ct-prod::S3::us-east-1::cloudtruth-s3::parameters/jmespath.json
      # aws://ct-conserv-prod@943604981792/us-east-1/s3/?r=cloudtruth-s3/parameters/jmespath.json
      # GitHub::Darryl Diosomito::repositories::341583244::dio-ct/cloud-management-integration::main::jmespath.json
      # github://dio-ct/cloud-management-integration/main/jmespath.json
      def convert_fqn(fqn)
        parts = fqn.split("::")
        base_fqn = parts[0..1].join('::')
        new_base_fqn = @integration_mapping[base_fqn]
        raise "No fqn mapping from '#{base_fqn}' => '#{new_base_fqn}'" unless new_base_fqn

        case parts[0]
          when /aws/i
            type = parts[2].downcase
            region = parts[3]
            bucket = parts[4]
            path = parts[5]
            new_fqn = "#{new_base_fqn}/#{region}/#{type}/?r=#{bucket}/#{path}"
          when /github/i
            org, repo = parts[4].split('/')
            branch = parts[5]
            path = parts[6]
            new_fqn = "#{new_base_fqn}/#{repo}/#{branch}/#{path}"
          else
            raise "Unknown integration"
        end

        new_fqn
      end

      def execute
        use_cli(ENV['CT_CLI_NEW_PATH'] || "cloudtruth")
        set_dry_run(@dry_run, %w[set unset delete])

        if cloudtruth(*%w(--version)) !~ /1\.0/
          raise "Import needs cloudtruth cli == 1.0.x"
        end

        json = JSON.load(File.read(@data_file))
        logger.info { "Import integrations:" }
        logger.info { json['integration'].pretty_inspect }
        puts

        integrations = JSON.parse(cloudtruth(*%w(integrations list --format json --values)))['integration'] rescue {}
        logger.info { "Existing integrations:" }
        logger.info { integrations.pretty_inspect }
        puts

        @integration_mapping = JSON.load(File.read("integration_mapping.json")) rescue {}
        logger.info { "Integration mappings:" }
        logger.info { @integration_mapping.pretty_inspect }
        puts

        if json['integration'].size != integrations.size
          raise "Integration count mismatch, create integrations in UI before proceeding"
        end

        if  json['integration'].size != @integration_mapping.size
          json['integration'].each do |i|
            puts "Enter new FQN for the integration:"
            puts i
            print "FQN: "
            fqn = gets.strip
            fqn = fqn.gsub(%r{/+$}, "") # remove trailing slash
            @integration_mapping[i["FQN"]] = fqn
          end

          output = JSON.pretty_generate(@integration_mapping)
          if @dry_run
            logger.info { "(DryRun) Skipping write of integration_mapping data: #{output}" }
          else
            File.write("integration_mapping.json", output)
          end
        end

        logger.info { "Creating environments" }
        json['environment'].each do |env|
          logger.info { "Creating '#{env['Name']}'" }
          cloudtruth(*%W(environments set --desc #{env['Description']} --parent #{env['Parent']} #{env['Name']}))
        end

        logger.info { "Creating projects" }
        json['project'].each do |proj|
          logger.info { "Creating '#{proj['Name']}'" }
          cloudtruth(*%W(projects set --desc #{proj['Description']} #{proj['Name']}))

          (proj['parameter'] || {}).each do |env, params|
            params.each do |param|
              if param['Source'] == env
                logger.info { "Creating parameter name='#{param['Name']}' for env='#{env}'" }
                cmd = %W(--project #{proj['Name']} --env #{env} parameter set --desc #{param['Description']} --secret #{param['Secret']})
                if param['FQN'].nil? || param['FQN'].strip.size == 0
                  cmd.concat  %W(--value #{param['Value']})
                else
                  cmd.concat %W(--fqn #{convert_fqn(param['FQN'])} --jmes #{param['JMES']})
                end
                cmd << param['Name']
                cloudtruth(*cmd)
              else
                logger.info { "Param value for '#{param['Name']}' doesn't exist in for env='#{env}'" }
              end
            end
          end

        end
      end
    end

  end
end