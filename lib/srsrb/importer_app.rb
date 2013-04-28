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
      parser.accept_upload params[:deck_file].fetch(:tempfile) if params[:deck_file]
      redirect request.url
    end

    private
    attr_accessor :parser
  end
end
