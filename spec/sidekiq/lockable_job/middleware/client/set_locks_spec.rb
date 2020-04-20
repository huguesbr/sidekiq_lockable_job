# https://github.com/mperham/sidekiq/wiki/Middleware
require 'sidekiq'
require 'fake_redis'

module Sidekiq::LockableJob
  module Middleware
    module Client
      RSpec.describe SetLocks do
        class LockableWorker
          include Sidekiq::Worker
          include Sidekiq::LockableJob
          def self.lockable_job_client_lock_keys(args)
            ['a', 'b']
          end

          def perform
          end
        end

        let(:lock_service) { worker_class.current_lockable_job_lock_service }
        subject { described_class.new }

        before(:each) do
          lock_service.unlock('a')
          lock_service.unlock('b')
        end

        RSpec.shared_examples 'it yield' do
          it do
            yielded = false
            subject.call(worker_class, {}, '', nil) do
              yielded = true
            end
            expect(yielded).to eq(true)
          end
        end

        describe 'LockableJob' do
          let(:worker_class) { LockableWorker }
          let(:lock_keys) { ['a', 'b'] }

          it_behaves_like 'it yield'

          RSpec.shared_examples 'set locks' do
            it 'set locks' do
              lock_keys.each { |lock_key| expect(lock_service.locked?(lock_key)).to eq(false) }
              subject.call(worker_class, {}, '', nil) {}
              lock_keys.each { |lock_key| expect(lock_service.locked?(lock_key)).to eq(true) }
            end
          end

          it_behaves_like 'set locks'

          context 'with single lock key' do
            class SingleKeyLockableWorker < LockableWorker
              def self.lockable_job_client_lock_keys(args)
                'a'
              end
            end

            let(:worker_class) { SingleKeyLockableWorker }
            let(:lock_keys) { ['a'] }

            it_behaves_like 'it yield'
            it_behaves_like 'set locks'
          end
        end
      end
    end
  end
end
