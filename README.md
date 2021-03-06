# Sidekiq::LockableJob

Prevent a job to run until another one complete.

[Sidekiq](https://github.com/mperham/sidekiq) includes a jobs dependencies mechanism to prevent a job from running before another one when enqueued.

But sometime your jobs will be enqueued independently, then for you do not know the job id on which you depend on (you could parse Sidekiq queue, but...)

`Sidekiq::LockableJob` allows you to set some locks ( based on job params ) when a job is enqueued or processed (store in redis), to prevent any other jobs to run if locked ( based on job params ) and will unlock any previously set locks ( based on job params ) when a job is **succesfully** completed.

## Use cases

For a real exemple at @Babylist.

Let's say a third party service send you a webhook request when some products of an order are shipped. (-> job A)
Then send you an eventual webhook request when some products of this order can not be shipped (without explicitely telling you which ones). (-> job B), on which you want to cancelled any non shipped products for this order.

Your third party service obviously send you this two webhook in the right order.
But if something went wrong processing the first job (database issue, ...), you might ended cancelled the full order because the first job A haven't run prior to the second job B.

In this scenario, you will request a lock `denied_order_cancellation_ABC` to be set when you first job A is enqueued (order key `ABC` being extracted from the job params), and you will request to raise a lock error (which will retry the job later) when the second job B is about to be processed if any lock exist for `denied_order_cancellation_ABC (order key `ABC` being extracted from the job params)`. And finally you will request an unlock of `denied_order_cancellation_ABC` when the first job A is **successfully** completed later on, which will allow the second job to succeed on its later retry.

> If you expect multiple job of type A to be enqueued and needs to wait for all this locks to be lift (using the same key), see `MultiLockService`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq_lockable_job'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sidekiq_lockable_job


## Demo

Thanks to [Asciinema](https://asciinema.org)!

    $ rake demo

[![asciicast](https://asciinema.org/a/324095.svg)](https://asciinema.org/a/324095)

## Usage

The gem is compose of four parts:

- Setting locks when job is **enqueued**
- Setting locks when job is **processed**
- Raising `Sidekiq::LockableJob::LockedJobError` when job **start** to processed but is locked
- Unsetting locks when job is **succesfully** processed

### Setting locks when job is **enqueued**

> happens in the sidekiq client middleware (on you rails app)
> including `Sidekiq::LockableJob` auto set the middleware chain

```ruby
require 'sidekiq_lockable_job'

class Worker
  include Sidekiq::Worker
  include Sidekiq::LockableJob

  def self.lockable_job_client_lock_keys(args)
    # jobs args are always in an array like **args
    lock_key = args.first['a_key']
    "some_context_prefix:#{lock_key}"
  end

  def perform
  end
end
```

When your job is **ENQUEUED** (`Worker.perform_async`), sidekiq LockableJob client middleware, will call `lockable_job_client_lock_keys` (before enqueuing the job) with the jobs arguments and set a lock for any returned keys

### Setting locks when job is processed

> happens in the sidekiq server middleware (on you rails worker)
> including `Sidekiq::LockableJob` auto set the middleware chain

```ruby
require 'sidekiq_lockable_job'

class Worker
  include Sidekiq::Worker
  include Sidekiq::LockableJob

  def self.lockable_job_server_lock_keys(args)
    # jobs args are always in an array like **args
    lock_key = args.first['a_key']
    "some_context_prefix:#{lock_key}"
  end

  def perform
  end
end
```

When your job is **PROCESSED**, sidekiq LockableJob server middleware, will call `lockable_job_client_lock_keys` (before running the job) with the jobs arguments and set a lock for any returned keys

### Raising `Sidekiq::LockableJob::LockedJobError` when job start to processed but is locked

> happens in the sidekiq server middleware (on you rails worker)
> including `Sidekiq::LockableJob` auto set the middleware chain

```ruby
require 'sidekiq_lockable_job'

class Worker
  include Sidekiq::Worker
  include Sidekiq::LockableJob

  def self.lockable_job_locked_by_keys(args)
    # jobs args are always in an array like **args
    lock_key = args.first['a_key']
    "some_context_prefix:#{lock_key}"
  end

  def perform
  end
end
```

When your job is **about** to be **processed**, sidekiq LockableJob server middleware, will call `lockable_job_locked_by_keys` (before processing the job) with the jobs arguments and raise `Sidekiq::LockableJob::LockedJobError` if any of the returned keys is locked.

> [Sidekiq Error Handling](https://github.com/mperham/sidekiq/wiki/Error-Handling)
> Sidekiq will retry failures with an exponential backoff using the formula (retry_count ** 4) + 15 + (rand(30) * (retry_count + 1)) (i.e. 15, 16, 31, 96, 271, ... seconds + a random amount of time). It will perform 25 retries over approximately 21 days. Assuming you deploy a bug fix within that time, the job will get retried and successfully processed. After 25 times, Sidekiq will move that job to the Dead Job queue, assuming that it will need manual intervention to work.

### Unsetting locks when job is **succesfully** processed

> happens in the sidekiq server middleware (on you rails worker)
> including `Sidekiq::LockableJob` auto set the middleware chain

```ruby
require 'sidekiq_lockable_job'

class Worker
  include Sidekiq::Worker
  include Sidekiq::LockableJob

  def self.lockable_job_unlock_keys(args)
    # jobs args are always in an array like **args
    lock_key = args.first['a_key']
    "some_context_prefix:#{lock_key}"
  end

  def perform
  end
end
```

When your job is **successfully** to be **performed**, sidekiq LockableJob server middleware, will call `lockable_job_unlock_keys` (after processing the job) with the jobs arguments and unset lock for any returned keys


## LockService vs MultiLockService vs CustomLockService

By default `Sidekiq::LockableJob` use `Sidekiq::LockableJob::LockService` to lock, unlock and check lock.
This service set lock time in redis when lock, unset redis key when unlock and check for redis key existance at lock check.

This is enough for most common scenario, but you can use `Sidekiq::LockableJob::MultiLockService` if you need to count the number of lock.
Each lock will increase the lock count, each unlock will decrease it, job will raise only if lock exist and count if > 0.

> If you're using both default lock and multi lock, keys handle by a lock should all use the same lock service
> see `lib/sidekiq/lockable_job/multi_lock_service.rb`

```ruby
require 'sidekiq_lockable_job'

class MultiLockWorker
  include Sidekiq::Worker
  include Sidekiq::LockableJob
  lockable_job_lock_service Sidekiq::LockableJob::MultiLockService
end
```

If you want to use your own locking mechanism (to store somewhere else than redis, or handle locked differently), you can set your own `LockService` class.

```ruby
module CustomLockService
  def self.lock(key)
    // do you own lock
  end

  def self.unlock(key)
    // do you own unlock
  end

  # non required helper method
  def self.locked?(key)
    // return true if locked
  end

  def self.handle_locked_by(key, worker_instance:, job:)
    // do you own handle if locked
    if locked?(key)
      worker_instance.class.perform_in(3.hours, **job['args'])
      return true
    end
    // return true if job should NOT run or false if it should
    false
  end
end

class Worker
  include Sidekiq::Worker
  include Sidekiq::LockableJob
  lockable_job_lock_service CustomLockService
end
```

## Roadmap

- [x] `Sidekiq::LockableJob` lock (on enqueuing, processing), unlock (on successfully processed), raise if locked (before processing)
- [x] `Sidekiq::LockableJob` auto add itself to sidekiq middleware
- [x] Supporting lock/unlock count (if a job is queued 3 times, will increase the lock count to 3, and will require 3 unlock to be lifted)
- [x] Externalize locking/unlocking/locked? mechanism (`LockableJobService`), and give option to use different service (ie.: not storing in Redis)
- [x] Option to requeue job (with delay), or swallow job failure if locked
- [ ] Option to no auto include to middleware (and use locks manually or add in different order in middleware chain)

## Specs

```
Sidekiq::LockableJob::LockService
  REDIS_PREFIX_KEY
    has a prefix
  .lock
    lock
  .unlock
    unlock
  .locked?
    true if locked
    false if NOT locked
  .handle_locked_by
    raise if locked by any key
    raise if locked by single key
    when not locked
      DOT NOT raise if not locked by
      return false

Sidekiq::LockableJob::Middleware::Client::SetLocks
  LockableJob
    behaves like it yield
      is expected to eq true
    behaves like set locks
      set locks
    with single lock key
      behaves like it yield
        is expected to eq true
      behaves like set locks
        set locks

Sidekiq::LockableJob::Middleware::Server::HandleLockedBy
  with no lock
    behaves like perform the job
      example at ./spec/sidekiq/lockable_job/middleware/server/shared.rb:13
    behaves like it yield
      is expected to eq true
  with lock set
    behaves like raise an error
      is expected to raise Sidekiq::LockableJob::LockedJobError
    with another lock key
      behaves like raise an error
        is expected to raise Sidekiq::LockableJob::LockedJobError
    with a non lock key
      behaves like perform the job
        example at ./spec/sidekiq/lockable_job/middleware/server/shared.rb:13
      behaves like it yield
        is expected to eq true
    with single lock key
      behaves like raise an error
        is expected to raise Sidekiq::LockableJob::LockedJobError

Sidekiq::LockableJob::Middleware::Server::SetLocks
  LockableJob
    set locks
    behaves like it yield
      is expected to eq true
    behaves like perform the job
      example at ./spec/sidekiq/lockable_job/middleware/server/shared.rb:13
    with single lock key
      set lock
      behaves like it yield
        is expected to eq true
      behaves like perform the job
        example at ./spec/sidekiq/lockable_job/middleware/server/shared.rb:13

Sidekiq::LockableJob::Middleware::Server::UnsetLocks
  with previous locks
    behaves like lock keys
      remove all locks
      behaves like it yield
        is expected to eq true
      behaves like perform the job
        example at ./spec/sidekiq/lockable_job/middleware/server/shared.rb:13
      for another job
        DOES NOT remove the lock
    with single lock key
      behaves like lock keys
        remove all locks
        behaves like it yield
          is expected to eq true
        behaves like perform the job
          example at ./spec/sidekiq/lockable_job/middleware/server/shared.rb:13
        for another job
          DOES NOT remove the lock

Sidekiq::LockableJob::MultiLockService
  REDIS_PREFIX_KEY
    has a prefix
  .lock
    lock
  .unlock
    unlock
    with multiple lock
      don't unlock at first
      unlock
  .locked?
    true if locked
    false if NOT locked
  .handle_locked_by
    raise if locked by any key
    raise if locked by single key
    when not locked
      DOT NOT raise if not locked by
      return false

Sidekiq::LockableJob
  .current_lockable_job_lock_service
    has lock_service by default
  .lockable_job_lock_service
    set a custom lock service
  .included
    include client middleware
    include server middleware (PENDING: Temporarily skipped with xit)

SidekiqLockableJob
  has a version number

Pending: (Failures listed here are expected and do not affect your suite's status)

  1) Sidekiq::LockableJob.included include server middleware
     # Temporarily skipped with xit
     # ./spec/sidekiq/lockable_job_spec.rb:37
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/huguesbr/sidekiq_lockable_job. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the sidekiq_lockable_job project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/huguesbr/sidekiq_lockable_job/blob/master/CODE_OF_CONDUCT.md).
