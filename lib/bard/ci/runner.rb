require "bard/ci/state"
require "bard/ci/retryable"

module Bard
  class CI
    class Runner < Struct.new(:project_name, :branch, :sha)
      include Retryable

      @runners = {}

      class << self
        attr_reader :runners

        def inherited(subclass)
          super
          name = extract_runner_name(subclass)
          runners[name] = subclass if name
        end

        def [](name)
          runners[name.to_sym]
        end

        # Returns the last registered runner (most recently loaded wins)
        def default
          runners.values.last
        end

        private

        def extract_runner_name(klass)
          klass.name&.split("::")&.last
            &.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            &.gsub(/([a-z\d])([A-Z])/, '\1_\2')
            &.downcase
            &.to_sym
        end
      end

      def run
        start
        @start_time = Time.new.to_i
        @last_time_elapsed = get_last_time_elapsed
        save_state
        wait_until_started

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

      def wait_until_started
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
