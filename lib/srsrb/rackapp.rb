require 'sinatra/base'
require 'srsrb/deck_view'

module SRSRB
  class RackApp < Sinatra::Base
    def self.assemble
      deck = DeckViewModel.new
      deck.enqueue_card(Card.new id: 0, question: 'question 1', answer: 'answer 1')
      self.new deck
    end

    def initialize deck_view
      super nil

      self.deck_view = deck_view
    end

    get '/reviews/' do
      card = deck_view.next_card
      if card 
        haml :question, locals: {card: card}
      else
        haml :no_more_reviews
      end
    end

    get '/reviews/:id' do
      card = deck_view.card_for(Integer(params[:id]))
      haml :answer, locals: {card: card}
    end

    private
    attr_accessor :deck_view
  end
end
