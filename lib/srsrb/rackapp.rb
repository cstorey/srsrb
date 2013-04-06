require 'sinatra/base'
require 'srsrb/deck_view'
require 'srsrb/decks'
require 'srsrb/event_store'
require 'srsrb/object_patch'
require 'lexical_uuid'
require 'haml'

module SRSRB
  class RackApp < Sinatra::Base
    def self.assemble
      event_store = EventStore.new
      deck_changes = Decks.new event_store
      deck = DeckViewModel.new event_store
      deck.start!

      default_deck_id = LexicalUUID.new
      deck_changes.name_model! default_deck_id, "Q&A"
      deck_changes.add_model_field! default_deck_id, "question"
      deck_changes.add_model_field! default_deck_id, "answer"

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
      model_id = deck_view.card_models.first
      redirect "/editor/new/#{model_id.to_guid}", 303
    end

    get '/editor/new/:model_id' do
      # Hack for the system tests
      last_card_id = session.delete :last_added_card_id
      model_id = LexicalUUID.new(params[:model_id])
      model = deck_view.card_model(model_id)
      haml :card_editor, locals: {
        last_card_id: last_card_id,
        card_models: deck_view.card_models.to_enum.flat_map { |model_id| [model_id.to_guid, deck_view.card_model(model_id).name] }.into { |kvs| Hash[*kvs] },
        card_fields: model.fields
      }
    end

    post '/editor/' do
      question = params.fetch('field-question', '')
      answer = params.fetch('field-answer', '')
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
        model_id = LexicalUUID.new

        decks.name_model! model_id, params[:model_name]
        decks.edit_model_templates! model_id, params[:question], params[:answer]
        fields.each do |f|
          decks.add_model_field! model_id, f
        end
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
