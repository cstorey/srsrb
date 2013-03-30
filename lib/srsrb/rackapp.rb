require 'sinatra/base'
require 'srsrb/deck_view'
require 'srsrb/decks'
require 'srsrb/event_store'

module SRSRB
  class RackApp < Sinatra::Base
    def self.assemble
      deck = DeckViewModel.new
      event_store = EventStore.new
      deck_changes = Decks.new event_store
      deck.enqueue_card(Card.new id: 0, question: 'question 1', answer: 'answer 1')
      deck.enqueue_card(Card.new id: 1, question: 'question 2', answer: 'answer 2')
      app = self.new deck, deck_changes
    end

    def initialize deck_view, decks
      super nil
      self.deck_view = deck_view
      self.decks = decks
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

    SCORES = { 'good' => :good }
    post '/reviews/:id' do
      score = SCORES.fetch(params.fetch('score'))
      id = Integer(params.fetch('id'))
      decks.score_card! Integer(id), score
      redirect '/reviews/', 303
    end


    get '/raw-cards/:id' do
      content_type :json
      card = deck_view.card_for(Integer(params[:id]))
      JSON.unparse(card.as_json)
    end

    private
    attr_accessor :deck_view, :decks
  end
end
