# frozen_string_literal: true

module ScriptTracker
  class Base
    class ScriptSkipped < StandardError; end
    class ScriptTimeoutError < StandardError; end

    class << self
      # Default timeout: 5 minutes
      # Override in subclass to customize:
      #   def self.timeout
      #     3600 # 1 hour
      #   end
      def timeout
        300 # 5 minutes in seconds
      end

      def run(_executed_script_record = nil)
        require 'timeout'
        start_time = Time.current
        timeout_seconds = timeout

        begin
          result = nil

          # Wrap execution in timeout if specified
          # WARNING: Ruby's Timeout.timeout has known issues and can interrupt code at any point,
          # potentially leaving resources in inconsistent states. Consider these alternatives:
          # 1. Implement timeout logic within your script using Time.current checks
          # 2. Use database statement_timeout for PostgreSQL
          # 3. Monitor script execution time and kill from outside if needed
          # This timeout is provided as a last resort safety measure.
          if timeout_seconds && timeout_seconds > 0
            Timeout.timeout(timeout_seconds, ScriptTimeoutError) do
              result = execute_with_transaction
            end
          else
            result = execute_with_transaction
          end

          duration = Time.current - start_time
          output = "Script completed successfully in #{duration.round(2)}s"
          log(output)

          { success: true, skipped: false, output: output, duration: duration }
        rescue ScriptSkipped => e
          duration = Time.current - start_time
          output = e.message.presence || 'Script was skipped (no action needed)'
          { success: false, skipped: true, output: output, duration: duration }
        rescue ScriptTimeoutError
          duration = Time.current - start_time
          error_message = "Script execution exceeded timeout of #{timeout_seconds} seconds"
          log(error_message, level: :error)
          { success: false, skipped: false, output: error_message, duration: duration }
        rescue StandardError => e
          duration = Time.current - start_time
          error_message = "#{e.class}: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
          log(error_message, level: :error)

          { success: false, skipped: false, output: error_message, duration: duration }
        end
      end

      def execute_with_transaction
        ActiveRecord::Base.transaction do
          execute
        end
      end

      def execute
        raise NotImplementedError, 'Subclasses must implement the execute method'
      end

      def skip!(reason = nil)
        message = reason ? "Skipping: #{reason}" : 'Skipping script'
        log(message)
        raise ScriptSkipped, message
      end

      def log(message, level: :info)
        timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S')
        prefix = level == :error ? '[ERROR]' : '[INFO]'
        puts "#{prefix} [#{timestamp}] #{message}"
      end

      def log_progress(current, total, message = nil)
        percentage = ((current.to_f / total) * 100).round(2)
        progress_detail = "(#{current}/#{total} - #{percentage}%)"
        msg = message ? "#{message} #{progress_detail}" : "Progress: #{current}/#{total} (#{percentage}%)"
        log(msg)
      end

      def process_in_batches(relation, batch_size: 1000, &block)
        total = relation.count
        log("There are #{total} records to process")
        return 0 if total == 0

        processed = 0
        log("Processing #{total} records in batches of #{batch_size}")
        relation.find_each(batch_size: batch_size) do |record|
          block.call(record)
          processed += 1
          log_interval = [batch_size, (total * 0.1).to_i].max
          log_progress(processed, total) if (processed % log_interval) == 0
        end
        log_progress(processed, total, 'Completed')
        processed
      end

      # Check if execution has exceeded timeout (safer alternative to Timeout.timeout)
      # Use this inside your scripts for manual timeout checking:
      #
      # def self.execute
      #   start_time = Time.current
      #   User.find_each do |user|
      #     check_timeout!(start_time, timeout)
      #     # Process user...
      #   end
      # end
      def check_timeout!(start_time, max_duration = timeout)
        elapsed = Time.current - start_time
        return unless max_duration&.positive? && elapsed > max_duration

        raise ScriptTimeoutError, "Script execution exceeded #{max_duration} seconds (elapsed: #{elapsed.round(2)}s)"
      end
    end
  end
end
