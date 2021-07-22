require_relative 'cloudtruth/migrator/logging'
# Need to setup logging before loading any other files
Cloudtruth::Migrator::Logging.setup_logging(level: :info, color: false)

require "active_support"

module Cloudtruth
  module Migrator
    VERSION = "0.0.1"
    class Error < StandardError; end
  end
end
