# https://github.com/mperham/sidekiq/wiki/Middleware
require 'sidekiq'
require 'fake_redis'

module Sidekiq::LockableJob
  module Middleware
    module Server
      RSpec.describe SetLocks do
        require_relative 'shared'

        class LockableWorker
          include Sidekiq::Worker
          include Sidekiq::LockableJob
          def self.lockable_job_server_lock_keys(args)
            ['a', 'b']
          end

          def perform
          end
        end

        let(:worker_class) { LockableWorker }
        subject { super().call(worker_class.new, {}, nil) {} }

        before(:each) do
          Sidekiq::LockableJob.unlock('a')
          Sidekiq::LockableJob.unlock('b')
        end

        describe 'LockableJob' do
          it_behaves_like 'it yield'
          it_behaves_like 'perform the job'

          it 'set locks' do
            expect(Sidekiq::LockableJob.locked?('a')).to eq(false)
            expect(Sidekiq::LockableJob.locked?('b')).to eq(false)
            subject
            expect(Sidekiq::LockableJob.locked?('a')).to eq(true)
            expect(Sidekiq::LockableJob.locked?('b')).to eq(true)
          end

          context 'with single lock key' do
            class SingleKeyLockableWorker < LockableWorker
              def self.lockable_job_server_lock_keys(args)
                'a'
              end
            end

            let(:worker_class) { SingleKeyLockableWorker }

            it_behaves_like 'it yield'
            it_behaves_like 'perform the job'

            it 'set lock' do
              expect(Sidekiq::LockableJob.locked?('a')).to eq(false)
              subject
              expect(Sidekiq::LockableJob.locked?('a')).to eq(true)
            end
          end
        end
      end
    end
  end
end
