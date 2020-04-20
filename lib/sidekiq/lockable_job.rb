require 'sidekiq'
require 'redis'
require_relative 'lockable_job/middleware/middleware.rb'

module Sidekiq
  module LockableJob
    class Error < StandardError; end
    class LockedJobError < StandardError; end

    LOCKABLE_JOB_REDIS_PREFIX_KEY = 'sidekiq_locks'

    def self.lock(key)
      redis.set(redis_key(key), Time.now)
    end

    def self.unlock(key)
      redis.del(redis_key(key))
    end

    def self.locked?(key)
      redis.exists(redis_key(key))
    end

    def self.raise_if_locked_by(keys)
      keys = [keys] unless keys.nil? || keys.is_a?(Array)
      keys&.each do |key|
        # perform in instead of retry?
        # perform_in(2.minutes, *args)
        raise LockedJobError.new("Locked by #{key}") if locked?(key)
      end
    end

    def self.redis_key(key)
      "#{LOCKABLE_JOB_REDIS_PREFIX_KEY}:#{key}"
    end

    def self.redis
      $redis = Redis.new
    end

    def self.included(base)
      unless base.ancestors.include? Sidekiq::Worker
        raise ArgumentError, "Sidekiq::LockableJob can only be included in a Sidekiq::Worker"
      end

      # base.extend(ClassMethods)

      # Automatically add sidekiq middleware when we're first included
      #
      # This might only occur when the worker class is first loaded in a
      # development rails environment, but that happens before the middleware
      # chain is invoked so we're all good.
      #
      Sidekiq.configure_server do |config|
        unless config.server_middleware.exists? Sidekiq::LockableJob::Middleware::Server::RaiseIfLocked
          config.server_middleware.add Sidekiq::LockableJob::Middleware::Server::RaiseIfLocked
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
  end
end
