require 'lexical_uuid'
require 'sinatra/base'
require 'rack/flash'
require 'hamster'

module SRSRB
  class ImporterApp < Sinatra::Base
    def initialize parser
      super nil
      self.parser = parser
    end

    use Rack::Flash

    set :dump_errors, true
    set :raise_errors, true

    get '/import/' do
      session[:foo]
      haml :importer
    end

    post '/import/' do
      if params[:deck_file]
        parser.accept_upload params[:deck_file].fetch(:tempfile)
        flash[:success] = "Deck imported"
      else
        flash[:error] = "No deck specified"
      end
      redirect request.url
    end

    private
    attr_accessor :parser
  end
end
