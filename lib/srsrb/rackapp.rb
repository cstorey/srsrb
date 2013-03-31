require 'sinatra/base'
require 'srsrb/deck_view'
require 'srsrb/decks'
require 'srsrb/event_store'

module SRSRB
  class RackApp < Sinatra::Base
    def self.assemble
      event_store = EventStore.new
      deck_changes = Decks.new event_store
      deck = DeckViewModel.new event_store
      deck.start!

      deck.enqueue_card(Card.new id: 0, question: 'question 1', answer: 'answer 1')
      deck.enqueue_card(Card.new id: 1, question: 'question 2', answer: 'answer 2')
      app = self.new deck, deck_changes
    end

    def initialize deck_view, decks
      super nil
      self.deck_view = deck_view
      self.decks = decks
    end

    use Rack::Session::Cookie, :key => 'rack.session',
                           #:domain => 'foo.com',
                           :path => '/',
                           :expire_after => 2592000, # In seconds
                           :secret => 'change_me'


    get '/reviews/' do
      card = deck_view.next_card_upto current_day
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


    # Hack for system tests
    get '/raw-cards/:id' do
      content_type :json
      card = deck_view.card_for(Integer(params[:id]))
      JSON.unparse(card.as_json)
    end

    # Hack for system tests
    get '/review-upto' do
      day = Integer(params[:day])
      self.current_day = day
    end

    private

    def current_day
      session[:current_day] || 0
    end

    def current_day= day
      session[:current_day] = day
    end

    attr_accessor :deck_view, :decks
  end
end
