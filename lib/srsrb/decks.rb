require 'srsrb/events'
require 'hamster/hash'
require 'atomic'

# TODO: Split according to usage:
#
# CardEditorApp	decks.add_or_edit_card
# CardEditorApp	decks.set_model_for_card
#
# ModelEditorApp	decks.add_model_field
# ModelEditorApp	decks.edit_model_templates
# ModelEditorApp	decks.name_model
#
# ReviewsApp	decks.score_card

module SRSRB
  class Models
    def initialize event_store
      self.event_store = event_store
      self.models = Atomic.new Hamster.hash
    end

    def start!
      event_store.subscribe self
    end

    def fetch id
      models.get[id]
    end

    def handle_event id, event, _version
      return unless event.kind_of? ModelFieldAdded
      models.update do |models|
        models.fetch(id) { CardModel.new(fields: Hamster.set) }.
        into { |model| model.set_fields model.fields.add(event.field) }.
        into { |model| models.put(id, model) }
      end
    end

    private
    attr_accessor :event_store, :models
  end
  class CardModel < Hamsterdam::Struct.define :fields; end
end
