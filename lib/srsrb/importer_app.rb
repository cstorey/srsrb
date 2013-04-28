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

    get '/import/' do
      haml :importer
    end

    post '/import/' do
      if params[:deck_file]
        parser.accept_upload params[:deck_file].fetch(:tempfile)
      else
        redirect request.url
      end
    end

    private
    attr_accessor :parser
  end
end
