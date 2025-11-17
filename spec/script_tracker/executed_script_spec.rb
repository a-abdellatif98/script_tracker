# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScriptTracker::ExecutedScript do
  describe 'validations' do
    it 'requires filename' do
      script = described_class.new(executed_at: Time.current, status: 'success')
      expect(script).not_to be_valid
      expect(script.errors[:filename]).to include("can't be blank")
    end

    it 'requires executed_at' do
      script = described_class.new(filename: 'test.rb', status: 'success')
      expect(script).not_to be_valid
      expect(script.errors[:executed_at]).to include("can't be blank")
    end

    it 'requires status' do
      script = described_class.new(filename: 'test.rb', executed_at: Time.current, status: nil)
      script.status = nil # Clear default value
      expect(script).not_to be_valid
      expect(script.errors[:status]).to include("can't be blank")
    end

    it 'validates status inclusion' do
      script = described_class.new(
        filename: 'test.rb',
        executed_at: Time.current,
        status: 'invalid'
      )
      expect(script).not_to be_valid
      expect(script.errors[:status]).to include('is not included in the list')
    end

    it 'validates uniqueness of filename' do
      described_class.create!(
        filename: 'test.rb',
        executed_at: Time.current,
        status: 'success'
      )

      duplicate = described_class.new(
        filename: 'test.rb',
        executed_at: Time.current,
        status: 'success'
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:filename]).to include('has already been taken')
    end

    it 'validates timeout is greater than 0' do
      script = described_class.new(
        filename: 'test.rb',
        executed_at: Time.current,
        status: 'success',
        timeout: -5
      )
      expect(script).not_to be_valid
      expect(script.errors[:timeout]).to include('must be greater than 0')
    end
  end

  describe 'scopes' do
    before do
      described_class.create!(filename: 'success1.rb', executed_at: 1.day.ago, status: 'success')
      described_class.create!(filename: 'success2.rb', executed_at: 2.days.ago, status: 'success')
      described_class.create!(filename: 'failed.rb', executed_at: Time.current, status: 'failed')
      described_class.create!(filename: 'running.rb', executed_at: Time.current, status: 'running')
      described_class.create!(filename: 'skipped.rb', executed_at: Time.current, status: 'skipped')
    end

    it 'filters successful scripts' do
      expect(described_class.successful.count).to eq(2)
    end

    it 'filters failed scripts' do
      expect(described_class.failed.count).to eq(1)
    end

    it 'filters running scripts' do
      expect(described_class.running.count).to eq(1)
    end

    it 'filters skipped scripts' do
      expect(described_class.skipped.count).to eq(1)
    end

    it 'filters completed scripts' do
      expect(described_class.completed.count).to eq(3)
    end

    it 'orders scripts by executed_at ascending' do
      scripts = described_class.ordered.pluck(:filename)
      expect(scripts.first).to eq('success2.rb')
    end

    it 'orders scripts by executed_at descending' do
      scripts = described_class.recent_first.pluck(:filename)
      expect(scripts.first).to be_in(['failed.rb', 'running.rb', 'skipped.rb'])
    end
  end

  describe '.executed?' do
    it 'returns true if script exists' do
      described_class.create!(filename: 'test.rb', executed_at: Time.current, status: 'success')
      expect(described_class.executed?('test.rb')).to be true
    end

    it 'returns false if script does not exist' do
      expect(described_class.executed?('nonexistent.rb')).to be false
    end
  end

  describe '.mark_as_running' do
    it 'creates a new script with running status' do
      script = described_class.mark_as_running('test.rb')
      expect(script.filename).to eq('test.rb')
      expect(script.status).to eq('running')
      expect(script.executed_at).to be_within(1.second).of(Time.current)
    end
  end

  describe '.cleanup_stale_running_scripts' do
    it 'marks stale running scripts as failed' do
      stale_script = described_class.create!(
        filename: 'stale.rb',
        executed_at: 2.hours.ago,
        status: 'running'
      )

      recent_script = described_class.create!(
        filename: 'recent.rb',
        executed_at: 30.minutes.ago,
        status: 'running'
      )

      described_class.cleanup_stale_running_scripts

      expect(stale_script.reload.status).to eq('failed')
      expect(stale_script.output).to include('stale running status')
      expect(recent_script.reload.status).to eq('running')
    end
  end

  describe '#mark_success!' do
    it 'updates status to success' do
      script = described_class.create!(filename: 'test.rb', executed_at: Time.current, status: 'running')
      script.mark_success!('Output text', 1.5)

      expect(script.reload.status).to eq('success')
      expect(script.output).to eq('Output text')
      expect(script.duration).to eq(1.5)
    end
  end

  describe '#mark_failed!' do
    it 'updates status to failed' do
      script = described_class.create!(filename: 'test.rb', executed_at: Time.current, status: 'running')
      script.mark_failed!('Error message', 2.3)

      expect(script.reload.status).to eq('failed')
      expect(script.output).to eq('Error message')
      expect(script.duration).to eq(2.3)
    end
  end

  describe '#mark_skipped!' do
    it 'updates status to skipped' do
      script = described_class.create!(filename: 'test.rb', executed_at: Time.current, status: 'running')
      script.mark_skipped!('Skipped message', 0.5)

      expect(script.reload.status).to eq('skipped')
      expect(script.output).to eq('Skipped message')
      expect(script.duration).to eq(0.5)
    end
  end

  describe 'status predicates' do
    it '#success? returns true for success status' do
      script = described_class.new(status: 'success')
      expect(script.success?).to be true
    end

    it '#failed? returns true for failed status' do
      script = described_class.new(status: 'failed')
      expect(script.failed?).to be true
    end

    it '#running? returns true for running status' do
      script = described_class.new(status: 'running')
      expect(script.running?).to be true
    end

    it '#skipped? returns true for skipped status' do
      script = described_class.new(status: 'skipped')
      expect(script.skipped?).to be true
    end
  end

  describe '#formatted_duration' do
    it 'returns N/A for nil duration' do
      script = described_class.new(duration: nil)
      expect(script.formatted_duration).to eq('N/A')
    end

    it 'formats duration in milliseconds' do
      script = described_class.new(duration: 0.5)
      expect(script.formatted_duration).to eq('500.0ms')
    end

    it 'formats duration in seconds' do
      script = described_class.new(duration: 5.5)
      expect(script.formatted_duration).to eq('5.5s')
    end

    it 'formats duration in minutes and seconds' do
      script = described_class.new(duration: 125.5)
      expect(script.formatted_duration).to eq('2m 5.5s')
    end
  end

  describe '#formatted_output' do
    it 'returns No output for blank output' do
      script = described_class.new(output: nil)
      expect(script.formatted_output).to eq('No output')
    end

    it 'truncates long output' do
      long_output = 'a' * 600
      script = described_class.new(output: long_output)
      expect(script.formatted_output.length).to be <= 503 # 500 + '...'
    end
  end

  describe '#timeout_seconds' do
    it 'returns custom timeout if set' do
      script = described_class.new(timeout: 600)
      expect(script.timeout_seconds).to eq(600)
    end

    it 'returns default timeout if not set' do
      script = described_class.new(timeout: nil)
      expect(script.timeout_seconds).to eq(300)
    end
  end

  describe '#timed_out?' do
    it 'returns false if not running' do
      script = described_class.new(status: 'success', timeout: 300, executed_at: 1.hour.ago)
      expect(script.timed_out?).to be false
    end

    it 'returns false if no timeout set' do
      script = described_class.new(status: 'running', timeout: nil, executed_at: 1.hour.ago)
      expect(script.timed_out?).to be false
    end

    it 'returns true if execution time exceeds timeout' do
      script = described_class.new(
        status: 'running',
        timeout: 60,
        executed_at: 2.hours.ago
      )
      expect(script.timed_out?).to be true
    end

    it 'returns false if execution time is within timeout' do
      script = described_class.new(
        status: 'running',
        timeout: 3600,
        executed_at: 30.minutes.ago
      )
      expect(script.timed_out?).to be false
    end
  end
end
