require 'lexical_uuid'
require 'sinatra/base'
require 'rack/flash'
require 'hamster'

module SRSRB
  class CardEditorApp < Sinatra::Base
    def initialize deck_view, decks, child=nil
      super child
      self.deck_view = deck_view
      self.decks = decks
    end

    use Rack::Flash

    get '/editor/new' do
      show_card_edit_form_for_default_model
    end

    def show_card_edit_form_for_default_model
      model_id = deck_view.card_models.first
      if model_id
        redirect "/editor/new/#{model_id.to_guid}", 303
      else
        haml :card_model_missing
      end
    end

    get '/editor/new/:model_id' do
      show_card_edit_form_for_model
    end

    def show_card_edit_form_for_model
      # Hack for the system tests
      last_card_id = session.delete :last_added_card_id

      model_id = LexicalUUID.new(params[:model_id])
      model = deck_view.card_model(model_id)

      haml :card_editor, locals: {
        last_card_id: last_card_id,
        card_models: card_models_as_dictionary,
        card_fields: model.fields
      }
    end

    def card_models_as_dictionary
      deck_view.card_models.to_enum.
        flat_map { |model_id| [model_id.to_guid, deck_view.card_model(model_id).name] }.
        into { |kvs| Hash[*kvs] }
    end

    post '/editor/new/:model_id' do
      add_new_card!
    end

    def add_new_card!
      model_id = LexicalUUID.new(params[:model_id])
      model = deck_view.card_model(model_id)


      # Hack for the system tests
      id = LexicalUUID.new

      decks.add_or_edit_card! id, model_id, form_fields_for_model_as_dictionary(model)

      session[:last_added_card_id] = id
      flash[:success] = "Your card has now been saved"
      redirect '/editor/new', 303
    end

    def form_fields_for_model_as_dictionary model
      fields = model.fields.to_enum.flat_map { |f| [f, params["field-#{f}"]] }.into { |kvs| Hash[*kvs] }
    end

    get '/editor/' do
      show_card_list
    end

    def show_card_list
      haml :card_editor_list, locals: { deck_view: deck_view }
    end

    get '/editor/:card_id' do
      show_card_edit_form params[:card_id]
    end

    def show_card_edit_form card_id
      card_id = LexicalUUID.new(card_id)
      card = deck_view.editable_card_for(card_id)
      haml :card_editor, locals: {
        last_card_id: nil,
        card_models: [], # TODO
        card_fields: card.fields,
        model_id: card.model_id.to_guid
      }
    end

    post '/editor/:card_id' do
      save_card!
    end

    def save_card!
      card_id = LexicalUUID.new(params[:card_id])
      model_id = LexicalUUID.new(params[:model_id])
      card_fields = params.flat_map { |k, v|
        m = /^field-(.*)/.match(k)
        m ? [m[1], v] : []
      }.into { |kvs| Hash[*kvs] }

      decks.add_or_edit_card! card_id, model_id, card_fields
      flash[:success] = "Your card has now been saved"
      redirect "/editor/#{card_id.to_guid}", 303
    end

    private
    attr_accessor :deck_view, :decks
  end
end
