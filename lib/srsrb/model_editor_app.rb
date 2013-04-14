require 'sinatra/base'
require 'rack/flash'
require 'lexical_uuid'

module SRSRB
  class ModelEditorApp < Sinatra::Base
    def initialize deck_view, decks, child=nil
      super child
      self.deck_view = deck_view
      self.decks = decks
    end

    use Rack::Flash

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
      flash[:success] = "Your model has now been saved"
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

end
