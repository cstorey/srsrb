require 'sinatra/base'
require 'rack-flash'
require 'lexical_uuid'
require 'srsrb/object_patch'
require 'haml'
require 'srsrb/reviews_app'
require 'srsrb/card_editor_app'
require 'srsrb/model_editor_app'

module SRSRB
  class SystemTestHackApi < Sinatra::Base
    def initialize child, deck_view, card_editing, model_editing
      @child = child
      super child
      self.deck_view = deck_view
      self.card_editing = card_editing
      self.model_editing = model_editing
    end

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
