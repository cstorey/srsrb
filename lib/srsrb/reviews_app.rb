require 'sinatra/base'
require 'lexical_uuid'

module SRSRB
  class ReviewsApp < Sinatra::Base
    def initialize deck_view, decks, child=nil
      super child
      self.deck_view = deck_view
      self.decks = decks
    end

    get '/reviews/' do
      show_next_question
    end

    def show_next_question
      card = deck_view.next_card_upto current_day
      if card 
        haml :question, locals: {card: card}
      else
        haml :no_more_reviews
      end
    end

    get '/reviews/:id' do
      show_answer_for_id
    end

    def show_answer_for_id
      id = LexicalUUID.new params.fetch('id')
      card = deck_view.card_for(id)
      haml :answer, locals: {card: card}
    end

    SCORES = {
      'good' => :good,
      'poor' => :poor,
      'fail' => :fail,
    }

    post '/reviews/:id' do
      score_card!
    end

    def score_card!
      score = SCORES.fetch(params.fetch('score'))
      id = LexicalUUID.new params.fetch('id')
      decks.score_card! id, score
      redirect '/reviews/', 303
    end

    private
    def current_day
      session[:current_day] || 0
    end


    attr_accessor :deck_view, :decks
  end
end
