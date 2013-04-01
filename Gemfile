source "https://rubygems.org/"
ruby ENV.fetch("RUBY_VERSION", "1.9.3")

gem 'sinatra'
gem 'hamster'
gem 'hamsterdam'
gem 'haml'
gem 'lexical_uuid'

group :production do
    gem 'puma'
end

group :test do
    gem 'capybara'
    gem 'rake'
    gem 'rspec'
end

group :development do
    gem 'guard'
    gem 'guard-rspec'
    gem 'rb-fsevent', '~> 0.9'
    gem 'launchy'
end
