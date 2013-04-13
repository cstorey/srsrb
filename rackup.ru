require 'srsrb/main'
require 'rack/static'

app = SRSRB::Main.assemble

use Rack::Static, :urls => %w{/css /js /img}, :root => 'public'
run app
