require 'sinatra/base'
require 'lexical_uuid'
require 'srsrb/object_patch'
require 'haml'

module SRSRB
  class ReviewsApp < Sinatra::Base
    def initialize deck_view, decks, child=nil
      super child
      self.deck_view = deck_view
      self.decks = decks
    end

    use Rack::Session::Cookie, :key => 'rack.session',
                           #:domain => 'foo.com',
                           :path => '/',
                           :expire_after => 2592000, # In seconds
                           :secret => 'change_me'


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

  class CardEditorApp < Sinatra::Base
    def initialize deck_view, decks, child=nil
      super child
      self.deck_view = deck_view
      self.decks = decks
    end

    use Rack::Session::Cookie, :key => 'rack.session',
                           #:domain => 'foo.com',
                           :path => '/',
                           :expire_after => 2592000, # In seconds
                           :secret => 'change_me'

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

      decks.set_model_for_card! id, model_id
      decks.add_or_edit_card! id, form_fields_for_model_as_dictionary(model)

      session[:last_added_card_id] = id
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
      card = deck_view.editable_card_for(card_id)
      haml :card_editor, locals: {
        last_card_id: nil,
        card_models: [], # TODO
        card_fields: card.fields.keys
      }
    end

    private
    attr_accessor :deck_view, :decks
  end

  class ModelEditorApp < Sinatra::Base
    def initialize deck_view, decks, child=nil
      super child
      self.deck_view = deck_view
      self.decks = decks
    end

    use Rack::Session::Cookie, :key => 'rack.session',
                           #:domain => 'foo.com',
                           :path => '/',
                           :expire_after => 2592000, # In seconds
                           :secret => 'change_me'


    # Model editing
    get '/model/new' do
      show_new_model_form
    end

    def show_new_model_form
      model_name = params[:model_name]

      maybe_commit_model!
      haml :model_editor, locals: {fields: model_fields_from_form, model_name: model_name}
    end

    def maybe_commit_model!
      return if params[:action] != 'commit'

      model_id = LexicalUUID.new

      decks.name_model! model_id, params[:model_name]
      decks.edit_model_templates! model_id, params[:question], params[:answer]

      model_fields_from_form.each do |f|
        decks.add_model_field! model_id, f
      end
    end


    def model_fields_from_form
      @model_fields_from_form ||= begin
        fields = params[:field_name] || []
        fields.reject!(&:nil?)
        fields.reject!(&:empty?)
        fields << params[:new_field_name] if params[:action] == 'add-field'
        fields
      end
    end

    private
    attr_accessor :deck_view, :decks
  end

  class SystemTestHackApi < Sinatra::Base
    def initialize child, deck_view, card_editing, model_editing
      @child = child
      super child
      self.deck_view = deck_view
      self.card_editing = card_editing
      self.model_editing = model_editing
    end

    use Rack::Session::Cookie, :key => 'rack.session',
                           #:domain => 'foo.com',
                           :path => '/',
                           :expire_after => 2592000, # In seconds
                           :secret => 'change_me'


    get '/raw-cards/:id' do
      raw_card_json_hack
    end
    #
    # Hack for system tests
    get '/review-upto' do
      set_review_upto_day!
    end

    # Hack for system tests
    put '/editor/raw' do
      inject_model_with_cards!
    end

    def raw_card_json_hack
      content_type :json
      id = LexicalUUID.new params.fetch('id')
      card = deck_view.card_for id
      JSON.unparse(card.as_json)
    end

    def set_review_upto_day!
      day = Integer(params[:day])
      self.current_day = day
    end

    def inject_model_with_cards!
      data = JSON.parse(request.body.read)

      model_id = inject_model! data
      inject_cards! model_id, data
      'OK'
    end

    def inject_model! data
      model = data.fetch('model')
      model_id = LexicalUUID.new(model.fetch('id'))

      model.fetch('fields').each do |f|
        model_editing.add_model_field! model_id, f
      end

      model_editing.edit_model_templates!(model_id, model.fetch('question_template'), model.fetch('answer_template'))
      model_id
    end

    def inject_cards! model_id, data
      data.fetch("cards").each do |item|
        inject_a_card! model_id, item
      end
    end

    def inject_a_card! model_id, item
      id = LexicalUUID.new(item.fetch("id"))
      fields = item.fetch("data")
      card_editing.set_model_for_card! id, model_id
      card_editing.add_or_edit_card! id, fields
    end

    private
    def current_day= day
      session[:current_day] = day
    end

    attr_accessor :deck_view, :card_editing, :model_editing
  end
end
