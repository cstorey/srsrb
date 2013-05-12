require 'hamsterdam'
require 'srsrb/events'
require 'lexical_uuid'

module SRSRB
  class FieldMissingException < RuntimeError;
    def initialize got, missing
      @got = got
      @missing = missing
    end

    def message
      "Missing fields: #{missing.inspect}, got: #{got.inspect}"
    end

    attr_reader :missing, :got
  end

  class CardEditing
    def initialize event_store, models
      self.event_store = event_store
      self.models = models
    end

    def add_or_edit_card! id, model_id, data
      card = get_card(id)
      expected_fields = models.fetch(model_id).fields
      missing_fields = (expected_fields - data.keys)
      raise FieldMissingException.new(data.keys, missing_fields) if not missing_fields.empty?

      event_store.record! id, 
        CardEdited.new(card_fields: Hamster.hash(data), model_id: model_id),
       card.version
    end

    private

    class Card < Hamsterdam::Struct.define :id, :version, :model_id, :event_store
      def apply event, version
        set_version(version)
      end
    end

    def get_card id
      event_store.to_enum(:events_for_stream, id).
        inject(Card.new id: id, event_store: event_store) { |card, (event, version)|
          card.apply(event, version)
      }
    end

    def version_of id
      get_card(id).version
    end
    attr_accessor :event_store, :models
  end
end
