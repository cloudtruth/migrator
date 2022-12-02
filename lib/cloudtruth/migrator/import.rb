require 'json'
require 'pp'
require 'tempfile'
require_relative 'runner'

module Cloudtruth
  module Migrator

    class Import < Clamp::Command
      include GemLogger::LoggerSupport
      include Runner

      def execute
        logger.debug { self }
        use_cli(ENV['CT_CLI_IMPORT_BINARY'] || "cloudtruth")
        set_dry_run(@dry_run, %w[set unset delete])
        set_continue_on_failure(@continue_on_failure)

        skip_integrations = false
        json = JSON.load(File.read(@data_file))
        integrations = cloudtruth(*%w(integrations list --format json --values), json_key: 'integration', allow_empty: true) || {}
        missing = json['integrations'].collect {|i| i['FQN']}.sort - integrations.collect {|i| i['FQN']}.sort
        if missing.size > 0
          logger.info { "Import integrations:" }
          logger.info { json['integrations'].pretty_inspect }
  
          logger.info { "Existing integrations:" }
          logger.info { integrations.pretty_inspect }

          logger.warn { "Integrations missing in destination, skipping any values that use them" }
          skip_integrations = true
        end

        logger.info { "Creating environments" }
        envs_by_parent = json['environments'].values.group_by {|e| e["parent"] }
        ordered_envs = envs_by_parent.delete(nil)
        ordered_envs.each do |oe|
          each_level_envs = envs_by_parent.delete(oe["name"])
          ordered_envs.concat(each_level_envs) if each_level_envs
        end
        logger.debug { "Environment creation order: #{ordered_envs.inspect}"}
        ordered_envs.each do |env|
          logger.info { "Creating '#{env['name']}'" }
          cloudtruth(*%W(environments set --desc #{env['description']} --parent #{env['parent']} #{env['name']}))
        end

        logger.info { "Creating projects" }
        projs_by_parent = json['projects'].values.group_by {|e| e["parent"] }
        ordered_projs = projs_by_parent.delete(nil)
        ordered_projs.each do |oe|
          each_level_projs = projs_by_parent.delete(oe["name"])
          ordered_projs.concat(each_level_projs) if each_level_projs
        end
        logger.debug { "Project creation order: #{ordered_projs.inspect}"}

        ordered_projs.each do |proj|
          logger.info { "Creating '#{proj['name']}'" }
          cmd = %W(projects set --desc #{proj['description']})
          cmd.concat %W(--parent #{proj["parent"]}) if proj["parent"]
          cmd << proj['name']
          cloudtruth(*cmd)

          proj['parameters'].values.each do |param|
            param['values'].values.each do |param_value|
              logger.info { "Creating parameter name='#{param['name']}' for env='#{param_value['environment']}'" }
              cmd = %W(--project #{proj['name']} --env #{param_value['environment']} parameter set --desc #{param['description']} --evaluate #{param_value['evaluated']})
              if param_value['external'].nil?
                cmd.concat  %W(--secret #{param['secret']} --value #{param_value['value']})
              else
                if skip_integrations
                  logger.warn "Skipping external value: #{param_value.inspect}"
                  next
                end
                fqn = param_value['external']['fqn']
                jmes = param_value['external']['jmes_path']
                secret = param['secret']
                secret = "true" if fqn =~ /^aws:/
                cmd.concat %W(--secret #{secret} --fqn #{fqn})
                cmd.concat %W(--jmes #{jmes}) if jmes
              end
              cmd << param['name']
              cloudtruth(*cmd)
            end
          end

          proj['templates'].values.each do |tmpl|
            logger.info { "Creating template name='#{tmpl['name']}'" }
            Tempfile.create('import-tmpl') do |file|
              file.write(tmpl['text'])
              file.flush
              cmd = %W(--project #{proj['name']} template set --desc #{tmpl['description']} --body #{file.path} #{tmpl['name']})
              cloudtruth(*cmd)
            end
          end

        end

        logger.info { "Import complete" }
      end

    end

  end
end
