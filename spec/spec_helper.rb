# frozen_string_literal: true

require 'bundler/setup'
require 'active_record'
require 'script_tracker'
require 'database_cleaner/active_record'

# Configure ActiveRecord for testing
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Load schema
ActiveRecord::Schema.define do
  create_table :executed_scripts, force: true do |t|
    t.string :filename, null: false
    t.datetime :executed_at, null: false
    t.string :status, null: false, default: 'running'
    t.text :output
    t.float :duration
    t.integer :timeout
    t.timestamps
  end

  add_index :executed_scripts, :filename, unique: true
  add_index :executed_scripts, :status
  add_index :executed_scripts, :executed_at
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Database Cleaner configuration
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
