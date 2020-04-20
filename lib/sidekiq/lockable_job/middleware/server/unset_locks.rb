# https://github.com/mperham/sidekiq/wiki/Middleware
require 'sidekiq'

module Sidekiq::LockableJob
  module Middleware
    module Server
      class UnsetLocks
        # @param [Object] worker the worker instance
        # @param [Hash] job the full job payload
        #   * @see https://github.com/mperham/sidekiq/wiki/Job-Format
        # @param [String] queue the name of the queue the job was pulled from
        # @yield the next middleware in the chain or worker `perform` method
        # @return [Void]
        def call(worker, job, queue)
          yield
          worker_klass = worker.class
          if worker_klass.respond_to?(:lockable_job_unlock_keys)
            keys = worker_klass.send(:lockable_job_unlock_keys, job['args'])
            keys = [keys] unless keys.nil? || keys.is_a?(Array)
            keys&.compact&.each do |key|
              Sidekiq::LockableJob.unlock(key)
            end
          end
        end
      end
    end
  end
end
