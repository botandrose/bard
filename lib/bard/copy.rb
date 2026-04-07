module Bard
  class Copy
    @handlers = []

    class << self
      def inherited(subclass)
        super
        @handlers.unshift(subclass)
      end

      def file(path, from:, to:, verbose: false)
        handler_for!(from, to).new(path, from, to, verbose).file
      end

      def dir(path, from:, to:, verbose: false)
        handler_for!(from, to).new(path, from, to, verbose).dir
      end

      private

      def handler_for!(from, to)
        handler = @handlers.find { |h| h.can_handle?(from, to) }
        raise "No copy handler for #{from.key} -> #{to.key}" unless handler
        handler
      end
    end

    attr_reader :path, :from, :to, :verbose

    def initialize(path, from, to, verbose)
      @path = path
      @from = from
      @to = to
      @verbose = verbose
    end

    def file
      raise NotImplementedError
    end

    def dir
      raise NotImplementedError
    end
  end
end
