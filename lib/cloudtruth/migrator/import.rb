require "json"
require "pp"
require "tempfile"
require_relative "runner"

module Cloudtruth
  module Migrator

    class Import < Clamp::Command
      include GemLogger::LoggerSupport
      include Runner

      def create_project_parameters(projects, skip_integrations)
        projects_with_errors = []

        projects.each do |proj|
          proj["parameters"].values.each do |param|
            param["values"].values.each do |param_value|
              logger.info { "Creating parameter name='#{param["name"]}' for env='#{param_value["environment"]}'" }
              cmd = %W(
                --project #{proj["name"]}
                --env #{param_value["environment"]}
                parameter set
                --evaluate #{param_value["evaluated"]}
              )

              if param.include?('description') && !param['description'].strip.empty?
                cmd.concat %W(--desc #{param["description"]})
              end

              if param_value["external"].nil?
                cmd.concat %W(--secret #{param["secret"]} --value #{param_value["value"]})
              else
                if skip_integrations
                  logger.warn "Skipping external value: #{param_value.inspect}"
                  next
                end
                fqn = param_value["external"]["fqn"]
                jmes = param_value["external"]["jmes_path"]
                secret = param["secret"]
                secret = "true" if fqn =~ /^aws:/
                cmd.concat %W(--secret #{secret} --fqn #{fqn})
                cmd.concat %W(--jmes #{jmes}) if jmes
              end

              cmd << param["name"]
              begin
                cloudtruth(*cmd)
              rescue StandardError => se
                projects_with_errors.append(proj)
                logger.warn { "Caught: #{se.message}" }
              end
            end
          end
        end
        if projects_with_errors.size > 0
          logger.warn { "Failed to import all parameters. Retrying #{projects_with_errors.size} parameters"}
          create_project_parameters(projects_with_errors, skip_integrations)
        end
      end

      def create_project_templates(projects)
        projects.each do |project|
          project["templates"].values.each do |tmpl|
            logger.info { "Creating template name='#{tmpl["name"]}'" }
            Tempfile.create("import-tmpl") do |file|
              file.write(tmpl["text"])
              file.flush

              cmd = %W(--project #{project["name"]} template set)
              if tmpl.include?('description') && (!tmpl['description'].nil? && !tmpl['description'].strip.empty?)
                cmd.concat %W(--desc #{tmpl["description"]})
              end
              cmd.concat %W(--body #{file.path} #{tmpl["name"]})
              cloudtruth(*cmd)
            end
          end
        end
      end

      def execute
        logger.debug { self }
        use_cli(ENV["CT_CLI_IMPORT_BINARY"] || "cloudtruth")
        set_dry_run(@dry_run, %w[set unset delete])
        set_continue_on_failure(@continue_on_failure)
        set_data_file(@data_file)

        logger.info { "Reading exported file: #{@data_file}" }
        json = JSON.load(File.read(@data_file))

        logger.info { "Checking for integrations" }
        skip_integrations = false
        integrations = cloudtruth(*%w(integrations list --format json --values), json_key: "integration", allow_empty: true) || {}
        missing = json["integrations"].collect { |i| i["FQN"] }.sort - integrations.collect { |i| i["FQN"] }.sort
        if missing.size > 0
          logger.info { "Import integrations:" }
          logger.info { json["integrations"].pretty_inspect }

          logger.info { "Existing integrations:" }
          logger.info { integrations.pretty_inspect }

          logger.warn { "Integrations missing in destination, skipping any values that use them" }
          skip_integrations = true
        end

        logger.info { "Creating environments" }
        envs_by_parent = json["environments"].values.group_by { |e| e["parent"] }
        ordered_envs = envs_by_parent.delete(nil)
        ordered_envs.each do |oe|
          each_level_envs = envs_by_parent.delete(oe["name"])
          ordered_envs.concat(each_level_envs) if each_level_envs
        end

        logger.debug { "Environment creation order: #{ordered_envs.inspect}" }
        ordered_envs.each do |env|
          logger.info { "Creating '#{env["name"]}'" }
          cmd = %W(environments set --parent #{env["parent"]} #{env["name"]})
          if env.include?('description') && !env['description'].strip.empty?
            cmd.concat %W(--desc #{env["description"]})
          end
          cloudtruth(*cmd)
        end

        logger.info { "Creating projects" }
        projects_by_parent = json["projects"].values.group_by { |e| e["parent"] }
        ordered_projects = projects_by_parent.delete(nil)
        ordered_projects.each do |oe|
          each_level_projects = projects_by_parent.delete(oe["name"])
          ordered_projects.concat(each_level_projects) if each_level_projects
        end
        logger.debug { "Project creation order: #{ordered_projects.inspect}" }

        ordered_projects.each do |proj|
          logger.info { "Creating '#{proj["name"]}'" }
          cmd = %W(projects set)
          if proj.include?('description') && !proj['description'].strip.empty?
            cmd.concat %W(--desc #{proj["description"]})
          end
          cmd.concat %W(--parent #{proj["parent"]}) if proj["parent"]
          cmd << proj["name"]
          cloudtruth(*cmd)
        end

        create_project_parameters(ordered_projects, skip_integrations)
        create_project_templates(ordered_projects)

        logger.info { "Import complete" }
      end

    end
  end
end
