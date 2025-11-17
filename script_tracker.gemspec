# frozen_string_literal: true

require_relative 'lib/script_tracker/version'

Gem::Specification.new do |spec|
  spec.name = 'script_tracker'
  spec.version = ScriptTracker::VERSION
  spec.authors = ['Ahmed Abd El-Latif']
  spec.email = ['ahmed.abdelatife@gmail.com']

  spec.summary = 'A Ruby gem for tracking and managing one-off script executions in Rails applications'
  spec.description = 'ScriptTracker provides a migration-like system for managing one-off scripts with execution tracking, ' \
                     'transaction support, and built-in logging. Perfect for data migrations, cleanup tasks, and administrative scripts.'
  spec.homepage = 'https://github.com/a-abdellatif98/script_tracker'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/a-abdellatif98/script_tracker'
  spec.metadata['changelog_uri'] = 'https://github.com/a-abdellatif98/script_tracker/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob([
                          'lib/**/*',
                          'tasks/**/*',
                          'templates/**/*',
                          'LICENSE',
                          'README.md',
                          'CHANGELOG.md'
                        ]).select { |f| File.file?(f) }

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'activerecord', '>= 6.0'
  spec.add_dependency 'activesupport', '>= 6.0'

  # Development dependencies
  spec.add_development_dependency 'database_cleaner-active_record', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'sqlite3', '~> 2.0'
end
