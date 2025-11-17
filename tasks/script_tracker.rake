# frozen_string_literal: true

namespace :scripts do
  desc 'Create a new script'
  task :create, [:description] => :environment do |_task, args|
    description = args[:description]

    if description.blank?
      puts 'Usage: rake scripts:create["description"]'
      exit 1
    end

    timestamp = Time.current.strftime('%Y%m%d%H%M%S')
    snake_case = description.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')
    filename = "#{timestamp}_#{snake_case}.rb"
    class_name = snake_case.camelize
    scripts_dir = ScriptTracker.scripts_path
    file_path = scripts_dir.join(filename)

    FileUtils.mkdir_p(scripts_dir)

    template = File.read(File.expand_path('../templates/script_template.rb', __dir__))
    timestamp_str = Time.current.strftime('%Y-%m-%d %H:%M:%S')
    content = template.gsub('<%= filename %>', filename)
                      .gsub('<%= description %>', description)
                      .gsub('<%= class_name %>', class_name)
                      .gsub('<%= Time.current.year %>', Time.current.year.to_s)
                      .gsub('<%= Time.current.strftime(\'%Y-%m-%d %H:%M:%S\') %>', timestamp_str)

    File.write(file_path, content)

    puts "\nCreated #{filename}"
    puts "Location: #{file_path}"
  end

  desc 'Run all pending scripts'
  task run: :environment do
    # Clean up any scripts that got stuck in "running" state
    stale_count = ScriptTracker::ExecutedScript.cleanup_stale_running_scripts
    puts "Cleaned up #{stale_count} stale script(s)\n\n" if stale_count > 0

    # Find all scripts that haven't run yet
    scripts_dir = ScriptTracker.scripts_path

    unless Dir.exist?(scripts_dir)
      puts "Error: Scripts directory does not exist: #{scripts_dir}"
      puts 'Please run: rails generate script_tracker:install'
      exit 1
    end

    all_scripts = Dir[scripts_dir.join('*.rb')].sort
    pending_scripts = all_scripts.reject { |f| ScriptTracker::ExecutedScript.executed?(File.basename(f)) }

    if pending_scripts.empty?
      puts "\nAll scripts are up to date. Nothing to run!"
      exit 0
    end

    success_count = 0
    failed_count = 0
    skipped_count = 0

    pending_scripts.each_with_index do |script_path, index|
      script_name = File.basename(script_path)
      puts "[#{index + 1}/#{pending_scripts.count}] Running #{script_name}..."

      # Try to acquire lock for this script
      lock_result = ScriptTracker::ExecutedScript.with_advisory_lock(script_name) do
        # Load script file using `load` (not `require`) because:
        # 1. Scripts are one-off files that should be loaded fresh each time
        # 2. Allows script modifications to be picked up without restart
        # 3. Scripts are not part of Rails autoload paths
        # Suppress warnings about already initialized constants
        original_verbosity = $VERBOSE
        $VERBOSE = nil
        load script_path
        $VERBOSE = original_verbosity

        # Extract and validate class name
        class_name = script_name.gsub(/^\d+_/, '').gsub('.rb', '').camelize
        script_class_name = "Scripts::#{class_name}"

        unless defined?(Scripts)
          puts "Error: Scripts module not found. Ensure script defines 'module Scripts'"
          failed_count += 1
          next
        end

        begin
          script_class = script_class_name.constantize
        rescue NameError => e
          puts "Error: Could not find class #{script_class_name}: #{e.message}"
          failed_count += 1
          next
        end

        # Validate script class
        unless script_class < ScriptTracker::Base
          puts "Error: Script class #{script_class_name} must inherit from ScriptTracker::Base"
          failed_count += 1
          next
        end

        unless script_class.respond_to?(:execute)
          puts "Error: Script class #{script_class_name} must implement the execute method"
          failed_count += 1
          next
        end

        # Mark as running and get timeout
        executed_script = ScriptTracker::ExecutedScript.mark_as_running(script_name)
        executed_script.update(timeout: script_class.timeout) if script_class.respond_to?(:timeout)
        start_time = Time.current

        # Run script with timeout support
        result = script_class.run(executed_script)
        duration = Time.current - start_time

        if result[:success]
          executed_script.mark_success!(result[:output], result[:duration] || duration)
          puts "Completed successfully in #{duration.round(2)}s\n\n"
          success_count += 1
        elsif result[:skipped]
          executed_script.mark_skipped!(result[:output], result[:duration] || duration)
          puts "Skipped in #{duration.round(2)}s\n\n"
          skipped_count += 1
        else
          executed_script.mark_failed!(result[:output], result[:duration] || duration)
          puts "Failed in #{duration.round(2)}s"
          puts "Error: #{result[:output]}\n\n"
          failed_count += 1
        end
      rescue LoadError => e
        puts "Error: Could not load script file #{script_name}: #{e.message}"
        failed_count += 1
      rescue SyntaxError => e
        puts "Error: Syntax error in script #{script_name}: #{e.message}"
        failed_count += 1
      rescue StandardError => e
        duration = begin
          (Time.current - start_time)
        rescue StandardError
          0
        end
        error_message = "#{e.class}: #{e.message}"
        executed_script&.mark_failed!(error_message, duration)
        puts "Error: #{e.message}\n\n"
        failed_count += 1
      end

      # Check if lock was not acquired
      if lock_result == { success: false, locked: false }
        puts "Skipped: Another process is already running #{script_name}\n\n"
        skipped_count += 1
      end
    end

    puts "Summary: #{success_count} succeeded, #{failed_count} failed, #{skipped_count} skipped"

    exit(1) if failed_count > 0
  end

  desc 'Show all scripts status'
  task status: :environment do
    scripts_dir = ScriptTracker.scripts_path

    unless Dir.exist?(scripts_dir)
      puts "Error: Scripts directory does not exist: #{scripts_dir}"
      puts 'Please run: rails generate script_tracker:install'
      exit 1
    end

    script_files = Dir[scripts_dir.join('*.rb')].sort
    executed_scripts = ScriptTracker::ExecutedScript.all.index_by(&:filename)

    if script_files.empty?
      puts "\nNo scripts found in #{scripts_dir}"
      puts 'Create a script with: rake scripts:create["description"]'
      exit 0
    end

    puts "\nScripts:"
    script_files.each do |file|
      filename = File.basename(file)
      if (script = executed_scripts[filename])
        status_icon = if script.success?
                        '[SUCCESS]'
                      elsif script.failed?
                        '[FAILED]'
                      else
                        script.skipped? ? '[SKIPPED]' : '[RUNNING]'
                      end
        puts "  #{status_icon} #{filename} (#{script.formatted_duration})"
      else
        puts "  [PENDING] #{filename}"
      end
    end
    puts
  end

  desc 'Rollback a script'
  task :rollback, [:filename] => :environment do |_task, args|
    filename = args[:filename]

    if filename.blank?
      puts 'Usage: rake scripts:rollback[filename.rb]'
      exit 1
    end

    script = ScriptTracker::ExecutedScript.find_by(filename: filename)
    if script.nil?
      puts "Script not found: #{filename}"
      exit 1
    end

    script.destroy!
    puts "Rolled back: #{filename}"
  end

  desc 'Cleanup stale scripts'
  task cleanup: :environment do
    count = ScriptTracker::ExecutedScript.cleanup_stale_running_scripts
    puts "Cleaned up #{count} stale script(s)"
  end
end
