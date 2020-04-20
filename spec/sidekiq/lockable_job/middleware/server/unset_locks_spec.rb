# https://github.com/mperham/sidekiq/wiki/Middleware
require 'sidekiq'
require 'fake_redis'

module Sidekiq::LockableJob
  module Middleware
    module Server
      RSpec.describe UnsetLocks do
        require_relative 'shared'

        class LockableWorker
          include Sidekiq::Worker
          include Sidekiq::LockableJob
          def self.lockable_job_unlock_keys(args)
            ['a', 'b']
          end

          def perform
          end
        end

        let(:worker_class) { LockableWorker }
        subject { super().call(worker_class.new, {}, nil) {} }

        context 'with previous locks' do
          let(:locked_keys) { ['a', 'b'] }

          before do
            locked_keys.each { |locked_key| Sidekiq::LockableJob.lock(locked_key) }
          end

          RSpec.shared_examples 'lock keys' do
            it_behaves_like 'it yield'
            it_behaves_like 'perform the job'

            it 'remove all locks' do
              locked_keys.each { |locked_key| expect(Sidekiq::LockableJob.locked?(locked_key)).to eq(true) }
              subject
              locked_keys.each { |locked_key| expect(Sidekiq::LockableJob.locked?(locked_key)).to eq(false) }
            end

            context 'for another job' do
              let(:locked_keys) { ['e', 'f'] }

              it 'DOES NOT remove the lock' do
                subject
                locked_keys.each { |locked_key| expect(Sidekiq::LockableJob.locked?(locked_key)).to eq(true) }
              end
            end
          end

          it_behaves_like 'lock keys'

          context 'with single lock key' do
            class SingleKeyLockableWorker < LockableWorker
              def self.lockable_job_unlock_keys(args)
                'a'
              end
            end

            let(:worker_class) { SingleKeyLockableWorker }
            let(:locked_keys) { ['a'] }

            it_behaves_like 'lock keys'
          end
        end
      end
    end
  end
end
