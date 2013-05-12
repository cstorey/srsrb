require 'hamsterdam'
require 'hamster/queue'
require 'hamster/hash'
require 'hamster/vector'
require 'atomic'

module SRSRB
  class CardEditorProjection
    def initialize event_store
      self.event_store = event_store
      self._card_models = Atomic.new Hamster.hash
      self._card_model_ids = Atomic.new Hamster.vector
      self._card_model_id_by_card = Atomic.new Hamster.hash
      self._editable_cards = Atomic.new(Hamster.hash)
    end

    def start!
      event_store.subscribe self
    end

    def card_models
      _card_model_ids.get
    end

    def card_model id
      _card_models.get.fetch(id)
    end

    def editable_card_for id
      _editable_cards.get[id]
    end

    def handle_event id, event, _version
      case event
        when CardEdited then handle_card_edited id, event
        when ModelNamed then handle_model_named id, event
        when ModelFieldAdded then handle_model_field_added id, event
      end
    end

    private
    def handle_model_field_added id, event
      update_model(id) { |old_model|
        model = old_model || Schema.new(id: id)
        model.set_fields model.fields.add(event.field)
      }
    end

    def update_model id, &block
      _card_models.update do |old_cards|
        old_model = old_cards[id]
        new_model = block.call old_model
        old_cards.put id, new_model
      end

      _card_model_ids.update { |ids| ids.include?(id) ? ids : ids.add(id) }
    end

    def handle_card_edited id, event
      _editable_cards.update { |oldver|
        oldver.put(id, EditableCard.new(id: id, fields: event.card_fields,
                                        model_id: event.model_id))
      }
    end

    def handle_model_named id, event
      update_model(id) { |model| model ||= Schema.new(id: id); model.set_name(event.name) }
    end

    attr_accessor :queue, :event_store, :_card_models, :_card_model_ids, :_card_model_id_by_card, :_editable_cards

    class Schema < Hamsterdam::Struct.define :id, :fields, :name
      def fields
        super || Hamster.vector
      end
    end
  end
 
  class EditableCard < Hamsterdam::Struct.define(:id, :fields, :model_id)
  end

end
