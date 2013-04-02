require 'sinatra/base'
require 'srsrb/deck_view'
require 'srsrb/decks'
require 'srsrb/event_store'
require 'lexical_uuid'
require 'haml'

module SRSRB
  class RackApp < Sinatra::Base
    def self.assemble
      event_store = EventStore.new
      deck_changes = Decks.new event_store
      deck = DeckViewModel.new event_store
      deck.start!

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
      score = SCORES.fetch(params.fetch('score'))
      id = LexicalUUID.new params.fetch('id')
      decks.score_card! id, score
      redirect '/reviews/', 303
    end

    get '/editor/new' do
      # Hack for the system tests
      last_card_id = session.delete :last_added_card_id
      haml :card_editor, locals: {last_card_id: last_card_id}
    end

    post '/editor/' do
      question = params.fetch('the-question')
      answer = params.fetch('the-answer')
      fields = Hash['question' => question, 'answer' => answer]
      id = LexicalUUID.new

      # Hack for the system tests
      session[:last_added_card_id] = id

      decks.add_or_edit_card! id, fields
      redirect '/editor/new', 303
    end

    # Model editing
    get '/model/new' do
      fields = [params[:field_name]].flatten.reject(&:nil?).reject(&:empty?)
      fields << params[:new_field_name] if params[:action] == 'add-field'
      model_name = params[:model_name]
      if params[:action] == 'commit'
        decks.add_or_edit_model! LexicalUUID.new, name: params[:model_name],
          fields: fields, question_template: params[:question],
          answer_template: params[:answer]
      end

      haml :model_editor, locals: {fields: fields, model_name: model_name}
    end

    # Hack for system tests
    get '/raw-cards/:id' do
      content_type :json
      id = LexicalUUID.new params.fetch('id')
      card = deck_view.card_for id
      JSON.unparse(card.as_json)
    end

    # Hack for system tests
    get '/review-upto' do
      day = Integer(params[:day])
      self.current_day = day
    end

    # Hack for system tests
    put '/editor/raw' do
      data = JSON.parse(request.body.read)
      data.each do |item|
        fail unless item.kind_of? Hash
        guid = item.fetch("id")
        id = LexicalUUID.new(guid)
        fields = item.fetch("data")
        decks.add_or_edit_card! id, fields
      end

      'OK'
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
