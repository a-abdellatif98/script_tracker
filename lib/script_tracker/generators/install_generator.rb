# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'
require 'rails/generators/active_record'

module ScriptTracker
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)
      desc "Creates ScriptTracker migration file and initializer"

      class_option :uuid, type: :boolean, default: true,
                   desc: "Use UUID for primary keys (requires database support)"

      class_option :skip_migration, type: :boolean, default: false,
                   desc: "Skip creating the migration file"

      class_option :skip_initializer, type: :boolean, default: false,
                   desc: "Skip creating the initializer file"

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def copy_migration
        return if options[:skip_migration]

        migration_template(
          "create_executed_scripts.rb.erb",
          "db/migrate/create_executed_scripts.rb",
          migration_version: migration_version
        )
      end

      def create_initializer
        return if options[:skip_initializer]

        template "initializer.rb", "config/initializers/script_tracker.rb"
      end

      def create_scripts_directory
        empty_directory "lib/scripts"
        create_file "lib/scripts/.keep"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end

      private

      def migration_version
        "[#{ActiveRecord::Migration.current_version}]"
      end

      def use_uuid?
        options[:uuid]
      end

      def primary_key_type
        use_uuid? ? ":uuid" : "true"
      end
    end
  end
end
