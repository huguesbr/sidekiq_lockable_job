require 'fake_redis'
require 'fakeredis/rspec'

module Sidekiq::LockableJob
  RSpec.describe LockService do
    let(:redis) { Redis.new }
    before do
      $redis = redis
    end

    describe 'REDIS_PREFIX_KEY' do
      it "has a prefix" do
        expect(described_class::REDIS_PREFIX_KEY).to eq('sidekiq::lockablejob::lockservice')
      end
    end

    describe '.lock' do
      it "lock" do
        described_class.lock('a')
        expect(redis.get("#{described_class::REDIS_PREFIX_KEY}:a").to_i).to eq(Time.now.to_i)
      end
    end

    describe '.unlock' do
      it "unlock" do
        described_class.lock('a')
        described_class.unlock('a')
        expect(redis.exists("#{described_class::REDIS_PREFIX_KEY}:a")).to be false
      end
    end

    describe '.locked?' do
      it "true if locked" do
        described_class.lock('a')
        expect(described_class.locked?('a')).to be true
      end

      it "false if NOT locked" do
        expect(described_class.locked?('a')).to be false
      end
    end

    describe '.handle_locked_by' do
      before do
        described_class.lock('a')
      end

      it "raise if locked by any key" do
        expect { described_class.handle_locked_by(['a', 'c'], worker_instance: nil, job: nil) }.to raise_error LockedJobError, 'Locked by a'
      end

      it "raise if locked by single key" do
        expect { described_class.handle_locked_by('a', worker_instance: nil, job: nil) }.to raise_error LockedJobError, 'Locked by a'
      end

      context 'when not locked' do
        it "DOT NOT raise if not locked by" do
          expect { described_class.handle_locked_by(['b'], worker_instance: nil, job: nil) }.not_to raise_error
        end

        it "return false" do
          #  (job is not locked and will be processed)
          expect(described_class.handle_locked_by(['b'], worker_instance: nil, job: nil)).to eq(false)
        end
      end
    end
  end
end
