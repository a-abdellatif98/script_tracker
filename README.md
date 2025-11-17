# ScriptTracker

ScriptTracker is a Ruby gem that provides a migration-like system for managing one-off scripts in Rails applications. It tracks script execution history, provides transaction support, and includes built-in logging and progress tracking.

## Features

- **Execution Tracking**: Automatically tracks which scripts have been run and their status
- **Transaction Support**: Wraps script execution in database transactions
- **Status Management**: Track scripts as success, failed, running, or skipped
- **Built-in Logging**: Convenient logging methods with timestamps
- **Batch Processing**: Helper methods for processing large datasets efficiently
- **Timeout Support**: Configure custom timeouts for long-running scripts
- **Stale Script Cleanup**: Automatically identify and cleanup stuck scripts
- **Migration Generator**: Generate timestamped script files with templates

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'script_tracker'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install script_tracker
```

## Setup

1. Install the gem using the generator:

```bash
rails generate script_tracker:install
```

This will:
- Create a migration for the `executed_scripts` table
- Create the `lib/scripts` directory for your scripts

2. Run the migration:

```bash
rails db:migrate
```

3. (Optional) Configure the scripts directory in an initializer:

```ruby
# config/initializers/script_tracker.rb
ScriptTracker.configure do |config|
  config.scripts_path = Rails.root.join('lib', 'scripts')
end
```

## Usage

### Creating a New Script

Generate a new script with a descriptive name:

```bash
rake scripts:create["update user preferences"]
```

This creates a timestamped script file in `lib/scripts/`:

```ruby
# lib/scripts/20231117120000_update_user_preferences.rb
module Scripts
  class UpdateUserPreferences < ScriptTracker::Base
    def self.execute
      log "Starting script: update user preferences"

      # Your script logic here
      User.find_each do |user|
        user.update!(preferences: { theme: 'dark' })
      end

      log "Script completed successfully"
    end
  end
end
```

### Running Scripts

Run all pending (not yet executed) scripts:

```bash
rake scripts:run
```

### Checking Script Status

View the status of all scripts:

```bash
rake scripts:status
```

Output:
```
Scripts:
  [SUCCESS] 20231117120000_update_user_preferences.rb (2.5s)
  [PENDING] 20231117130000_cleanup_old_data.rb
```

### Rolling Back a Script

Remove a script from execution history (allows it to be run again):

```bash
rake scripts:rollback[20231117120000_update_user_preferences.rb]
```

### Cleaning Up Stale Scripts

Mark scripts stuck in "running" status as failed:

```bash
rake scripts:cleanup
```

## Advanced Features

### Skipping Scripts

Skip a script execution conditionally:

```ruby
module Scripts
  class ConditionalUpdate < ScriptTracker::Base
    def self.execute
      if User.where(needs_update: true).count.zero?
        skip! "No users need updating"
      end

      # Your script logic here
    end
  end
end
```

### Custom Timeout

Override the default 5-minute timeout:

```ruby
module Scripts
  class LongRunningScript < ScriptTracker::Base
    def self.timeout
      3600 # 1 hour in seconds
    end

    def self.execute
      # Long-running logic here
    end
  end
end
```

### Batch Processing

Process large datasets efficiently:

```ruby
module Scripts
  class ProcessUsers < ScriptTracker::Base
    def self.execute
      users = User.where(processed: false)

      process_in_batches(users, batch_size: 1000) do |user|
        user.update!(processed: true)
      end
    end
  end
end
```

### Progress Logging

Track progress during execution:

```ruby
module Scripts
  class DataMigration < ScriptTracker::Base
    def self.execute
      total = User.count
      processed = 0

      User.find_each do |user|
        # Process user
        processed += 1
        log_progress(processed, total) if (processed % 100).zero?
      end
    end
  end
end
```

## API Reference

### ScriptTracker::Base

Base class for all scripts.

**Class Methods:**

- `execute` - Implement this method with your script logic (required)
- `run` - Execute the script with transaction and error handling
- `timeout` - Override to set custom timeout (default: 300 seconds)
- `skip!(reason)` - Skip script execution with optional reason
- `log(message, level: :info)` - Log a message with timestamp
- `log_progress(current, total, message = nil)` - Log progress percentage
- `process_in_batches(relation, batch_size: 1000, &block)` - Process records in batches

### ScriptTracker::ExecutedScript

ActiveRecord model for tracking script execution.

**Scopes:**

- `successful` - Scripts that completed successfully
- `failed` - Scripts that failed
- `running` - Scripts currently running
- `skipped` - Scripts that were skipped
- `completed` - Scripts that finished (success or failed)
- `ordered` - Order by execution time ascending
- `recent_first` - Order by execution time descending

**Class Methods:**

- `executed?(filename)` - Check if a script has been executed
- `mark_as_running(filename)` - Mark a script as running
- `cleanup_stale_running_scripts(older_than: 1.hour.ago)` - Clean up stale scripts

**Instance Methods:**

- `mark_success!(output, duration)` - Mark as successful
- `mark_failed!(error, duration)` - Mark as failed
- `mark_skipped!(output, duration)` - Mark as skipped
- `success?`, `failed?`, `running?`, `skipped?` - Status predicates
- `formatted_duration` - Human-readable duration
- `formatted_output` - Truncated output text
- `timeout_seconds` - Get timeout value
- `timed_out?` - Check if script has timed out

## Rake Tasks

- `rake scripts:create[description]` - Create a new script
- `rake scripts:run` - Run all pending scripts
- `rake scripts:status` - Show status of all scripts
- `rake scripts:rollback[filename]` - Rollback a script
- `rake scripts:cleanup` - Cleanup stale running scripts

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/blink-global/script_tracker.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
