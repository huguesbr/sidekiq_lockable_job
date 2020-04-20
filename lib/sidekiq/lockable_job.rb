require 'sidekiq'
require 'redis'
require_relative 'lockable_job/middleware/middleware.rb'
require_relative 'lockable_job/lock_service'
require_relative 'lockable_job/multi_lock_service'

module Sidekiq
  module LockableJob
    class Error < StandardError; end
    class LockedJobError < StandardError; end

    DEFAULT_LOCKABLE_JOB_SERVICE = LockService

    def self.included(base)
      unless base.ancestors.include? Sidekiq::Worker
        raise ArgumentError, "Sidekiq::LockableJob can only be included in a Sidekiq::Worker"
      end

      base.extend(ClassMethods)

      # Automatically add sidekiq middleware when we're first included
      #
      # This might only occur when the worker class is first loaded in a
      # development rails environment, but that happens before the middleware
      # chain is invoked so we're all good.
      #
      Sidekiq.configure_server do |config|
        unless config.client_middleware.exists? Sidekiq::LockableJob::Middleware::Server::SetLocks
          config.client_middleware.add Sidekiq::LockableJob::Middleware::Server::SetLocks
        end
        unless config.server_middleware.exists? Sidekiq::LockableJob::Middleware::Server::HandleLockedBy
          config.server_middleware.add Sidekiq::LockableJob::Middleware::Server::HandleLockedBy
        end
        unless config.server_middleware.exists? Sidekiq::LockableJob::Middleware::Server::UnsetLocks
          config.server_middleware.add Sidekiq::LockableJob::Middleware::Server::UnsetLocks
        end
      end
      Sidekiq.configure_client do |config|
        unless config.client_middleware.exists? Sidekiq::LockableJob::Middleware::Client::SetLocks
          config.client_middleware.add Sidekiq::LockableJob::Middleware::Client::SetLocks
        end
      end
    end

    module ClassMethods
      def current_lockable_job_lock_service
        @lockable_job_lock_service || DEFAULT_LOCKABLE_JOB_SERVICE
      end

      def lockable_job_lock_service(service)
        @lockable_job_lock_service = service
      end
    end
  end
end
