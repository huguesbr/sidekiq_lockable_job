require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'tty-prompt'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec


desc "Play a demo of contextualized_logs"
task :demo do
  prompt = TTY::Prompt.new
  if `which asciinema`.empty?
    if `which brew`.empty
      return unless prompt.yes?('Install brew')
      `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"`

      return unless prompt.yes?('Install asciinema using brew?')
      `brew install asciinema`
    end
  end
  prompt.warn('press [space] continuesly to play demo line by line, or just press [space] to play')
  exec('asciinema play -i 1 -s 1 demo.cast')
end
