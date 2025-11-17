# frozen_string_literal: true

module ScriptTracker
  class ExecutedScript < ActiveRecord::Base
    self.table_name = 'executed_scripts'

    # Constants
    DEFAULT_TIMEOUT = 300 # 5 minutes in seconds

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
