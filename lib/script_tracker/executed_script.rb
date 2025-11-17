# frozen_string_literal: true

module ScriptTracker
  class ExecutedScript < ActiveRecord::Base
    self.table_name = 'executed_scripts'

    # Constants
    DEFAULT_TIMEOUT = 300 # 5 minutes in seconds
    LOCK_KEY_PREFIX = 0x5343525054 # 'SCRPT' in hex for script tracker locks

    # Validations
    validates :filename, presence: true, uniqueness: true
    validates :executed_at, presence: true
    validates :status, presence: true, inclusion: { in: %w[success failed running skipped] }
    validates :timeout, numericality: { greater_than: 0, allow_nil: true }

    # Scopes
    scope :successful, -> { where(status: 'success') }
    scope :failed, -> { where(status: 'failed') }
    scope :running, -> { where(status: 'running') }
    scope :completed, -> { where(status: %w[success failed]) }
    scope :skipped, -> { where(status: 'skipped') }
    scope :ordered, -> { order(executed_at: :asc) }
    scope :recent_first, -> { order(executed_at: :desc) }

    # Class methods
    def self.executed?(filename)
      exists?(filename: filename)
    end

    def self.mark_as_running(filename)
      create!(
        filename: filename,
        executed_at: Time.current,
        status: 'running'
      )
    end

    def self.cleanup_stale_running_scripts(older_than: 1.hour.ago)
      stale_scripts = running.where('executed_at < ?', older_than)
      count = stale_scripts.count
      stale_scripts.update_all(
        status: 'failed',
        output: 'Script was marked as failed due to stale running status'
      )
      count
    end

    # Advisory lock methods for preventing concurrent execution
    def self.with_advisory_lock(filename)
      lock_acquired = acquire_lock(filename)
      return { success: false, locked: false } unless lock_acquired

      begin
        yield
      ensure
        release_lock(filename)
      end
    end

    def self.acquire_lock(filename)
      lock_id = generate_lock_id(filename)

      case connection.adapter_name.downcase
      when 'postgresql'
        # Use PostgreSQL advisory locks (non-blocking)
        result = connection.execute("SELECT pg_try_advisory_lock(#{lock_id})").first
        [true, 't'].include?(result['pg_try_advisory_lock'])
      when 'mysql', 'mysql2', 'trilogy'
        # Use MySQL named locks (timeout: 0 for non-blocking)
        result = connection.execute("SELECT GET_LOCK('script_tracker_#{lock_id}', 0) AS locked").first
        result['locked'] == 1 || result[0] == 1
      else
        # Fallback: use database record with unique constraint
        # This will raise an exception if script is already running
        begin
          exists?(filename: filename, status: 'running') == false
        rescue ActiveRecord::RecordNotUnique
          false
        end
      end
    rescue StandardError => e
      Rails.logger&.warn("Failed to acquire lock for #{filename}: #{e.message}")
      false
    end

    def self.release_lock(filename)
      lock_id = generate_lock_id(filename)

      case connection.adapter_name.downcase
      when 'postgresql'
        connection.execute("SELECT pg_advisory_unlock(#{lock_id})")
      when 'mysql', 'mysql2', 'trilogy'
        connection.execute("SELECT RELEASE_LOCK('script_tracker_#{lock_id}')")
      else
        # No-op for fallback strategy
        true
      end
    rescue StandardError => e
      Rails.logger&.warn("Failed to release lock for #{filename}: #{e.message}")
      false
    end

    def self.generate_lock_id(filename)
      # Generate a consistent integer ID from filename for advisory locks
      # Using CRC32 to convert string to integer
      require 'zlib'
      (LOCK_KEY_PREFIX << 32) | (Zlib.crc32(filename) & 0xFFFFFFFF)
    end

    # Instance methods
    def mark_success!(output_text = nil, execution_duration = nil)
      update!(
        status: 'success',
        output: output_text,
        duration: execution_duration
      )
    end

    def mark_failed!(error_message, execution_duration = nil)
      update!(
        status: 'failed',
        output: error_message,
        duration: execution_duration
      )
    end

    def mark_skipped!(output_text = nil, execution_duration = nil)
      update!(
        status: 'skipped',
        output: output_text,
        duration: execution_duration
      )
    end

    def success?
      status == 'success'
    end

    def failed?
      status == 'failed'
    end

    def running?
      status == 'running'
    end

    def skipped?
      status == 'skipped'
    end

    def formatted_duration
      return 'N/A' if duration.nil?

      if duration < 1
        "#{(duration * 1000).round(2)}ms"
      elsif duration < 60
        "#{duration.round(2)}s"
      else
        minutes = (duration / 60).floor
        seconds = (duration % 60).round(2)
        "#{minutes}m #{seconds}s"
      end
    end

    def formatted_output
      return 'No output' if output.blank?

      output.truncate(500)
    end

    def timeout_seconds
      timeout || DEFAULT_TIMEOUT
    end

    def timed_out?
      return false unless running? && timeout

      Time.current > executed_at + timeout.seconds
    end
  end
end
