require 'open3'
require 'json'

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

  def set_continue_on_failure(continue_on_failure)
    @continue_on_failure = continue_on_failure
  end

  def set_data_file(data_file)
    @data_file = data_file
  end

  def fail(msg)
    @continue_on_failure ? logger.error { msg } : raise(msg)
  end

  def cloudtruth(*cmd, json_key: nil, allow_empty: false)
    result = nil
    output = sh(*([@cli_path] + cmd))

    if json_key
      begin
        parsed = JSON.parse(output)
      rescue JSON::ParserError => e
        logger.debug { "Failed to parse json: #{e.message}" }
        parsed = {}
      end
      result = parsed[json_key]
      fail("The json key '#{json_key}' is not present in the command output: #{output}") if result.nil? && ! allow_empty
    else
      result = output
    end

    result
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

      unless status.success?
        fail("Command failed: #{cmd.join(' ')}")
      end

    end

    output
  end

end
