# frozen_string_literal: true

module ScriptTracker
  class Railtie < ::Rails::Railtie
    railtie_name :script_tracker

    rake_tasks do
      path = File.expand_path(__dir__)
      Dir.glob("#{path}/../../tasks/**/*.rake").each { |f| load f }
    end

    initializer 'script_tracker.configure' do |app|
      app.config.script_tracker = ActiveSupport::OrderedOptions.new
      app.config.script_tracker.scripts_path = app.root.join('lib', 'scripts')
    end
  end
end
