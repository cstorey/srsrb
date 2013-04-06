require "bundler"
Bundler.setup
require "rake"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new("test") do |spec|
  spec.rspec_opts = '-f doc --color --profile'
end

task default: :test

