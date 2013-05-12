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
      haml :importer
    end

    post '/import/' do
      importer.perform
      redirect request.url
    end

    def import_successful
      flash[:success] = "Deck imported"
    end

    def import_failed
      flash[:error] = "No deck specified"
    end

    private
    def importer
      if deck_file_stream.nil?
        DeckMissing.new(self)
      else
        ImportProcess.new(self, parser, deck_file_stream)
      end
    end

    def deck_file_stream
      params.fetch('deck_file', {})[:tempfile]
    end

    attr_accessor :parser
  end

  class DeckMissing
    def initialize client
      @client = client
    end
    def perform
      client.import_failed
    end

    private
    attr_reader :client
  end

  class ImportProcess
    def initialize client, parser, deck
      @client = client
      @parser = parser
      @deck = deck
    end

    def perform
      if deck
        parser.accept_upload deck
        client.import_successful
      else
        client.import_failed
      end
    end

    private
    attr_reader :client, :parser, :deck
  end
end
