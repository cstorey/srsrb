source "https://rubygems.org/"
ruby '1.9.3' unless ENV.has_key? 'RUBY_VERSION'

gem 'sinatra'
gem 'hamster',
  git: 'git://github.com/harukizaemon/hamster.git',
  ref: '0826fec977'
gem 'hamsterdam'
gem 'haml'
gem 'lexical_uuid'
gem 'atomic'

gem 'rack-flash3'

gem 'snappy'
gem 'leveldb-ruby'

# For Anki imports
gem 'sqlite3'
gem 'sequel'

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
    gem 'guard-bundler'
    gem 'rb-fsevent', '~> 0.9'
    gem 'launchy'
    gem 'mutant'
end
