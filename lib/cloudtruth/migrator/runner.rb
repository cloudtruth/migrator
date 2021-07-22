require 'open3'

module Runner
  extend ActiveSupport::Concern
  include GemLogger::LoggerSupport

  def use_cli(cli_path)
    @cli_path = cli_path
  end

  def set_dry_run(dry_run, triggers)
    @dry_run = dry_run
    @triggers = triggers
  end

  def cloudtruth(*cmd)
    sh(*([@cli_path] + cmd))
  end

  def sh(*cmd)
    output = ""
    if @dry_run && cmd.any? {|a| @triggers.any? {|t| a == t } }
      logger.info { "(DryRun) Skipping mutating command: #{cmd.inspect}" }
    else
      logger.debug { "Running command: #{cmd.inspect}" }
      result = Open3.capture2(*cmd)
      output = result[0]
      status = result[1]

      raise "Command failed: #{cmd.join(' ')}" unless status.success?
    end

    return output
  end

end
