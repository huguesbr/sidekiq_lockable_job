lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sidekiq_lockable_job/version"

Gem::Specification.new do |spec|
  spec.name          = "sidekiq_lockable_job"
  spec.version       = SidekiqLockableJob::VERSION
  spec.authors       = ["Hugues Bernet-Rollande"]
  spec.email         = ["hugues@xdev.fr"]

  spec.summary       = 'Prevent a job to run until another one complete'
  spec.description   = <<~EOF
  Sidekiq includes a jobs dependencies mechanism to prevent a job from running before another one when enqueued.

  But sometime your jobs will be enqueued independently, then for you do not know the job id on which you depend on (you could parse Sidekiq queue, but...)

  `SidekiqLockableJob` allows you to set some locks ( based on job params ) when a job is enqueued or processed (store in redis), to prevent any other jobs to run if locked ( based on job params ) and will unlock any previously set locks ( based on job params ) when a job is **succesfully** completed.
  EOF
  spec.homepage      = 'https://github.com/huguesbr/sidekiq_lockable_job'
  spec.license       = "MIT"


  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = 'https://github.com/huguesbr/sidekiq_lockable_job'
  spec.metadata["changelog_uri"] = 'https://github.com/huguesbr/sidekiq_lockable_job/README.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_dependency 'sidekiq', '5.0.5'
  spec.add_dependency 'redis', '4.0.1'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "fakeredis", '0.7.0'
  spec.add_development_dependency 'tty-prompt', '0.19.0'
end
