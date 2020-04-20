# https://github.com/mperham/sidekiq/wiki/Middleware
require 'sidekiq'

module Sidekiq::LockableJob
  module Middleware
    module Client
      class SetLocks
        # @param [String, Class] worker_class the string or class of the worker class being enqueued
        # @param [Hash] job the full job payload
        #   * @see https://github.com/mperham/sidekiq/wiki/Job-Format
        # @param [String] queue the name of the queue the job was pulled from
        # @param [ConnectionPool] redis_pool the redis pool
        # @return [Hash, FalseClass, nil] if false or nil is returned,
        #   the job is not to be enqueued into redis, otherwise the block's
        #   return value is returned
        # @yield the next middleware in the chain or the enqueuing of the job
        def call(worker_class, job, queue, redis_pool)
          worker_klass = worker_class.is_a?(String) ? worker_class.constantize : worker_class
          if worker_klass.respond_to?(:lockable_job_client_lock_keys)
            keys = worker_klass.send(:lockable_job_client_lock_keys, job['args'])
            keys = [keys] unless keys.nil? || keys.is_a?(Array)
            keys&.compact&.each do |key|
              Sidekiq::LockableJob.lock(key)
            end
          end
          yield
        end
      end
    end
  end
end
