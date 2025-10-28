module Bard
  class CI
    module Retryable
      MAX_RETRIES = 5
      INITIAL_DELAY = 1

      def retry_with_backoff(max_retries: MAX_RETRIES)
        retries = 0
        delay = INITIAL_DELAY

        begin
          yield
        rescue => e
          if retries < max_retries
            retries += 1
            puts "  Network error (attempt #{retries}/#{max_retries}): #{e.message}. Retrying in #{delay}s..."
            sleep(delay)
            delay *= 2
            retry
          else
            raise "Network error after #{max_retries} attempts: #{e.message}"
          end
        end
      end
    end
  end
end
