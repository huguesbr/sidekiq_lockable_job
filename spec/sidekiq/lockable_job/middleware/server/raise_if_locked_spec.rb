# https://github.com/mperham/sidekiq/wiki/Middleware
require 'sidekiq'
require 'fake_redis'

module Sidekiq::LockableJob
  module Middleware
    module Server
      RSpec.describe RaiseIfLocked do
        require_relative 'shared'

        class LockableWorker
          include Sidekiq::Worker
          include Sidekiq::LockableJob
          def self.lockable_job_locked_by_keys(args)
            ['a', 'b']
          end

          def perform
          end
        end

        let(:worker_class) { LockableWorker }
        subject { super().call(worker_class.new, {}, nil) {} }

        context 'with no lock' do
          it_behaves_like 'perform the job'
          it_behaves_like 'it yield'
        end

        context 'with lock set' do
          let(:lock_key) { 'a' }

          before do
            Sidekiq::LockableJob.lock(lock_key)
          end

          RSpec.shared_examples 'raise an error' do
            it do
              expect {
                subject
              }.to raise_error Sidekiq::LockableJob::LockedJobError
            end
          end

          it_behaves_like 'raise an error'

          context 'with another lock key' do
            let(:lock_key) { 'b' }

            it_behaves_like 'raise an error'
          end

          context 'with a non lock key' do
            let(:lock_key) { 'c' }

            it_behaves_like 'perform the job'
          end

          context 'with single lock key' do
            class SingleKeyLockableWorker < LockableWorker
              def self.lockable_job_locked_by_keys(args)
                'a'
              end
            end

            let(:worker_class) { SingleKeyLockableWorker }

            it_behaves_like 'raise an error'
          end
        end
      end
    end
  end
end
