# frozen_string_literal: true

module Ossert
  module Workers
    module ForkProcessing
      def self.included(base)
        base.send :include, Process
      end

      def process_in_fork(force: false)
        return yield if !force && (ENV['CI'] || ENV['TEST'])

        pid = fork { yield }
        waitpid(pid)
        sleep(5)
      end
    end
  end
end
