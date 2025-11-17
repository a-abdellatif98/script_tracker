# frozen_string_literal: true

# Script: <%= filename %>
# Created: <%= Time.current.strftime('%Y-%m-%d %H:%M:%S') %>
# Description: <%= description %>
#
# This script performs: [Describe what this script does]
#
# Prerequisites:
# - [List any prerequisites]
#
# Rollback plan:
# - [Describe how to rollback if needed]
#

module Scripts
  class <%= class_name %> < ScriptTracker::Base
    # Optional: Override timeout (default is 300 seconds / 5 minutes)
    # def self.timeout
    #   3600 # 1 hour
    # end

    def self.execute
      log "Starting script: <%= filename %>"

      # Example: Skip if work is already done
      # if condition_already_met?
      #   skip! "Reason for skipping"
      # end

      # Your script logic here

      log "Script completed successfully"
    end
  end
end

# Execute the script if run directly
if __FILE__ == $PROGRAM_NAME
  result = Scripts::<%= class_name %>.run
  exit(result[:success] ? 0 : 1)
end
