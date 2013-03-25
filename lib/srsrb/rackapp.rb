require 'sinatra/base'
require 'srsrb/deck_view'

module SRSRB
  class RackApp < Sinatra::Base
    def self.assemble
      self.new DeckViewModel.new
    end

    def initialize deck_view
      super nil

      self.deck_view = deck_view
    end
    get '/reviews' do
      q = deck_view.next_card
      if q
        haml :question, locals: {question: q}
      else
        haml :no_more_reviews
      end
    end

    private
    attr_accessor :deck_view
  end
end
