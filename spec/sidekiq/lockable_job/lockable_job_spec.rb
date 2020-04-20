require 'fake_redis'
require 'fakeredis/rspec'
require 'sidekiq'

module Sidekiq
  RSpec.describe LockableJob do
    let(:redis) { Redis.new }

    describe '.lock' do
      it "lock" do
        LockableJob.lock('a')
        expect(redis.get("#{LockableJob::LOCKABLE_JOB_REDIS_PREFIX_KEY}:a")).not_to be nil
      end
    end

    describe '.unlock' do
      it "unlock" do
        redis.set("#{LockableJob::LOCKABLE_JOB_REDIS_PREFIX_KEY}:a", Time.now)
        expect(redis.get("#{LockableJob::LOCKABLE_JOB_REDIS_PREFIX_KEY}:a")).not_to be nil
        LockableJob.unlock('a')
        expect(redis.get("#{LockableJob::LOCKABLE_JOB_REDIS_PREFIX_KEY}:a")).to be nil
      end
    end

    describe '.locked?' do
      it "true if locked" do
        redis.set("#{LockableJob::LOCKABLE_JOB_REDIS_PREFIX_KEY}:a", Time.now)
        expect(LockableJob.locked?('a')).to be true
      end

      it "false if NOT locked" do
        expect(LockableJob.locked?('a')).to be false
      end
    end

    describe '.raise_if_locked_by' do
      before do
        redis.set("#{LockableJob::LOCKABLE_JOB_REDIS_PREFIX_KEY}:a", Time.now)
      end

      it "raise if locked by any key" do
        expect { LockableJob.raise_if_locked_by(['a', 'c']) }.to raise_error LockableJob::LockedJobError, 'Locked by a'
      end

      it "raise if locked by single key" do
        expect { LockableJob.raise_if_locked_by('a') }.to raise_error LockableJob::LockedJobError, 'Locked by a'
      end

      it "DOT NOT raise if not locked by" do
        expect { LockableJob.raise_if_locked_by(['b']) }.not_to raise_error
      end
    end

    describe '.included' do
      class DummyWorker
        include Sidekiq::Worker
        include LockableJob
      end

      it 'include middlewares' do
        Sidekiq.configure_server do |config|
          expect(config.server_middleware.exists? Sidekiq::LockableJob::Middleware::Server::RaiseIfLocked).to eq(true)
          expect(config.server_middleware.exists? Sidekiq::LockableJob::Middleware::Server::UnsetLocks).to eq(true)
          expect(config.server_middleware.exists? Sidekiq::LockableJob::Middleware::Server::SetLocks).to eq(true)
        end
        Sidekiq.configure_client do |config|
          expect(config.client_middleware.exists? Sidekiq::LockableJob::Middleware::Client::SetLocks).to eq(true)
        end
      end
    end
  end
end
