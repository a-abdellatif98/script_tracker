# ScriptTracker

A Ruby gem that provides a migration-like system for managing one-off scripts in Rails applications with execution tracking, transaction support, and built-in logging.

## Features

* **Execution Tracking** - Automatically tracks which scripts have been run and their status
* **Transaction Support** - Wraps script execution in database transactions
* **Status Management** - Track scripts as success, failed, running, or skipped
* **Built-in Logging** - Convenient logging methods with timestamps
* **Batch Processing** - Helper methods for processing large datasets efficiently
* **Timeout Support** - Configure custom timeouts for long-running scripts

## Installation

Add to your Gemfile:

```ruby
gem 'script_tracker'
```

Then run:

```bash
bundle install
rails generate script_tracker:install
rails db:migrate
```

## Quick Start

### Create a Script

```bash
rake scripts:create["update user preferences"]
```

This creates a timestamped script file in `lib/scripts/` :

```ruby
module Scripts
  class UpdateUserPreferences < ScriptTracker::Base
    def self.execute
      log "Starting script"
      
      User.find_each do |user|
        user.update!(preferences: { theme: 'dark' })
      end
      
      log "Script completed"
    end
  end
end
```

### Run Scripts

```bash
rake scripts:run        # Run all pending scripts
rake scripts:status     # View script status
rake scripts:rollback[filename]  # Rollback a script
rake scripts:cleanup    # Cleanup stale scripts
```

## Advanced Usage

### Skip Script Conditionally

```ruby
def self.execute
  skip! "No users need updating" if User.where(needs_update: true).count.zero?
  # Your logic here
end
```

### Custom Timeout

```ruby
def self.timeout
  3600 # 1 hour in seconds
end
```

### Batch Processing

```ruby
def self.execute
  users = User.where(processed: false)
  process_in_batches(users, batch_size: 1000) do |user|
    user.update!(processed: true)
  end
end
```

### Progress Logging

```ruby
def self.execute
  total = User.count
  processed = 0
  
  User.find_each do |user|
    # Process user
    processed += 1
    log_progress(processed, total) if (processed % 100).zero?
  end
end
```

## API Reference

### ScriptTracker:: Base

**Class Methods:**
* `execute` - Implement with your script logic (required)
* `timeout` - Override to set custom timeout (default: 300 seconds)
* `skip!(reason)` - Skip script execution
* `log(message, level: :info)` - Log a message
* `log_progress(current, total)` - Log progress percentage
* `process_in_batches(relation, batch_size: 1000, &block)` - Process in batches

### ScriptTracker:: ExecutedScript

**Scopes:** `successful` , `failed` , `running` , `skipped` , `completed` , `ordered` , `recent_first`

**Class Methods:**
* `executed?(filename)` - Check if script has been executed
* `cleanup_stale_running_scripts(older_than: 1.hour.ago)` - Clean up stale scripts

## Rake Tasks

* `rake scripts:create[description]` - Create a new script
* `rake scripts:run` - Run all pending scripts
* `rake scripts:status` - Show status of all scripts
* `rake scripts:rollback[filename]` - Rollback a script
* `rake scripts:cleanup` - Cleanup stale running scripts

## Releasing

### GitHub Actions (Recommended)

1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Enter version number (e.g., `0.1.3`)

Or push a tag:

```bash
git tag -a v0.1.3 -m "Release version 0.1.3"
git push origin v0.1.3
```

**Required:** Set `RUBYGEMS_AUTH_TOKEN` in GitHub repository secrets.

### Local Release

```bash
bin/release 0.1.3
```

## Contributing

Bug reports and pull requests welcome at https://github.com/a-abdellatif98/script_tracker.

## License

MIT License - see LICENSE file for details.
