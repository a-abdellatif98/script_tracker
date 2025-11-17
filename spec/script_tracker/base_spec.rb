# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScriptTracker::Base do
  let(:test_script_class) do
    Class.new(described_class) do
      def self.execute
        log "Executing test script"
      end
    end
  end

  let(:failing_script_class) do
    Class.new(described_class) do
      def self.execute
        raise StandardError, "Test error"
      end
    end
  end

  let(:skipping_script_class) do
    Class.new(described_class) do
      def self.execute
        skip! "Test skip reason"
      end
    end
  end

  describe '.timeout' do
    it 'returns default timeout of 300 seconds' do
      expect(test_script_class.timeout).to eq(300)
    end

    it 'can be overridden in subclass' do
      custom_script = Class.new(described_class) do
        def self.timeout
          600
        end
      end

      expect(custom_script.timeout).to eq(600)
    end
  end

  describe '.run' do
    it 'executes the script successfully' do
      result = test_script_class.run

      expect(result[:success]).to be true
      expect(result[:skipped]).to be false
      expect(result[:output]).to include('Script completed successfully')
    end

    it 'wraps execution in a transaction' do
      expect(ActiveRecord::Base).to receive(:transaction).and_call_original
      test_script_class.run
    end

    it 'handles script failure' do
      result = failing_script_class.run

      expect(result[:success]).to be false
      expect(result[:skipped]).to be false
      expect(result[:output]).to include('StandardError: Test error')
    end

    it 'handles script skip' do
      result = skipping_script_class.run

      expect(result[:success]).to be false
      expect(result[:skipped]).to be true
      expect(result[:output]).to include('Test skip reason')
    end

    it 'includes duration in result' do
      result = test_script_class.run
      expect(result[:output]).to match(/\d+\.\d+s/)
    end
  end

  describe '.execute' do
    it 'raises NotImplementedError if not overridden' do
      expect do
        described_class.execute
      end.to raise_error(NotImplementedError, 'Subclasses must implement the execute method')
    end
  end

  describe '.skip!' do
    it 'raises ScriptSkipped with custom reason' do
      expect do
        test_script_class.skip!("Custom reason")
      end.to raise_error(ScriptTracker::Base::ScriptSkipped, /Custom reason/)
    end

    it 'raises ScriptSkipped with default message' do
      expect do
        test_script_class.skip!
      end.to raise_error(ScriptTracker::Base::ScriptSkipped, /Skipping script/)
    end
  end

  describe '.log' do
    it 'outputs info level messages' do
      expect do
        test_script_class.log("Test message")
      end.to output(/\[INFO\].*Test message/).to_stdout
    end

    it 'outputs error level messages' do
      expect do
        test_script_class.log("Error message", level: :error)
      end.to output(/\[ERROR\].*Error message/).to_stdout
    end

    it 'includes timestamp in output' do
      expect do
        test_script_class.log("Test message")
      end.to output(/\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]/).to_stdout
    end
  end

  describe '.log_progress' do
    it 'logs progress with percentage' do
      expect do
        test_script_class.log_progress(50, 100)
      end.to output(/Progress: 50\/100 \(50.0%\)/).to_stdout
    end

    it 'logs progress with custom message' do
      expect do
        test_script_class.log_progress(25, 100, "Processing records")
      end.to output(/Processing records \(25\/100 - 25.0%\)/).to_stdout
    end
  end

  describe '.process_in_batches' do
    let(:mock_relation) do
      double('ActiveRecord::Relation').tap do |rel|
        allow(rel).to receive(:count).and_return(5)
        allow(rel).to receive(:find_each).and_yield(1).and_yield(2).and_yield(3).and_yield(4).and_yield(5)
      end
    end

    it 'processes all records' do
      processed = []
      result = test_script_class.process_in_batches(mock_relation) do |record|
        processed << record
      end

      expect(result).to eq(5)
      expect(processed).to eq([1, 2, 3, 4, 5])
    end

    it 'returns 0 for empty relation' do
      empty_relation = double('ActiveRecord::Relation')
      allow(empty_relation).to receive(:count).and_return(0)

      result = test_script_class.process_in_batches(empty_relation) { |_record| }

      expect(result).to eq(0)
    end

    it 'respects custom batch size' do
      expect(mock_relation).to receive(:find_each).with(batch_size: 100)
      test_script_class.process_in_batches(mock_relation, batch_size: 100) { |_record| }
    end

    it 'logs progress during processing' do
      expect do
        test_script_class.process_in_batches(mock_relation) { |_record| }
      end.to output(/There are 5 records to process/).to_stdout
    end
  end
end
