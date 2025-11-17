# frozen_string_literal: true

require "script_tracker/version"
require "script_tracker/base"
require "script_tracker/executed_script"
require "script_tracker/railtie" if defined?(Rails::Railtie)

# Load generators for Rails
if defined?(Rails)
  require "rails/generators"
  require_relative "script_tracker/generators/install_generator"
end

module ScriptTracker
  class Error < StandardError; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def scripts_path
      configuration&.scripts_path || Rails.root.join('lib', 'scripts')
    end
  end

  class Configuration
    attr_accessor :scripts_path

    def initialize
      @scripts_path = nil
    end
  end
end
