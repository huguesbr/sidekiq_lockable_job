require 'fake_redis'
require 'fakeredis/rspec'
require 'sidekiq'
require 'sidekiq/lockable_job'

module Sidekiq
  RSpec.describe LockableJob do
    class LockableWorker
      include Worker
      include LockableJob
    end

    describe '.current_lockable_job_lock_service' do
      it 'has lock_service by default' do
        expect(LockableWorker.current_lockable_job_lock_service).to eq(LockableJob::LockService)
      end
    end

    describe '.lockable_job_lock_service' do
      class CustomLockService; end
      class CustomLockableWorker
        include Worker
        include LockableJob
        lockable_job_lock_service CustomLockService
      end

      it 'set a custom lock service' do
        expect(CustomLockableWorker.current_lockable_job_lock_service).to eq(CustomLockService)
      end
    end

    describe '.included' do
      it 'include client middleware' do
        expect(Sidekiq.client_middleware.exists? LockableJob::Middleware::Client::SetLocks).to eq(true)
      end

      xit 'include server middleware' do
        # how to test this?
        expect(Sidekiq.server_middleware.exists? LockableJob::Middleware::Server::HandleLockedBy).to eq(true)
        expect(Sidekiq.server_middleware.exists? LockableJob::Middleware::Server::UnsetLocks).to eq(true)
        expect(Sidekiq.server_middleware.exists? LockableJob::Middleware::Server::SetLocks).to eq(true)
      end
    end
  end
end
