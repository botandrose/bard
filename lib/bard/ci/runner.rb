require "bard/ci/state"
require "bard/ci/retryable"

module Bard
  class CI
    class Runner < Struct.new(:project_name, :branch, :sha)
      include Retryable

      def run
        start
        @start_time = Time.new.to_i
        @last_time_elapsed = get_last_time_elapsed
        save_state
        wait_until_started if respond_to?(:wait_until_started)

        poll_until_complete { |elapsed, last_time| yield elapsed, last_time }

        state.delete
        success?
      end

      def resume
        saved_state = state.load
        raise "No saved CI state found for #{project_name}. Start a new build with 'bard ci'." if saved_state.nil?

        restore_state(saved_state)
        poll_until_complete { |elapsed, last_time| yield elapsed, last_time }

        state.delete
        success?
      end

      protected

      def poll_until_complete
        while building?
          elapsed_time = Time.new.to_i - @start_time
          yield elapsed_time, @last_time_elapsed
          save_state
          sleep(2)
        end
      end

      def save_state
        state.save(get_state_data)
      end

      def state
        @state ||= State.new(project_name)
      end

      # Abstract methods - override in subclasses
      def start
        raise NotImplementedError, "#{self.class}#start not implemented"
      end

      def building?
        raise NotImplementedError, "#{self.class}#building? not implemented"
      end

      def success?
        raise NotImplementedError, "#{self.class}#success? not implemented"
      end

      def get_last_time_elapsed
        nil
      end

      def get_state_data
        raise NotImplementedError, "#{self.class}#get_state_data not implemented"
      end

      def restore_state(data)
        raise NotImplementedError, "#{self.class}#restore_state not implemented"
      end
    end
  end
end
