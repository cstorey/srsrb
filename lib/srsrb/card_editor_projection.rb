require 'hamsterdam'
require 'hamster/queue'
require 'hamster/hash'
require 'hamster/vector'
require 'atomic'

module SRSRB
  class CardEditorProjection
    def initialize event_store
      self.event_store = event_store
      self.cards = Atomic.new Hamster.hash
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
        when ModelTemplatesChanged then handle_model_templates_changed id, event
      end
    end

    private
    def handle_model_field_added id, event
      update_model(id) { |old_model|
        model = old_model || CardFormat.new(id: id)
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

    def handle_model_templates_changed id, event
      update_model(id) { |model|
        model ||= CardFormat.new id: id
        model.set_question_template(event.question).set_answer_template(event.answer)
      }
    end

    def handle_card_edited id, event
      # TODO: Updates the projection of all cards in the deck. Needs
      # replacing with a table of fact fields by model.
      cards.update { |oldver|
          oldver.put(id, Card.new(id: id))
      }

      _editable_cards.update { |oldver|
        oldver.put(id, EditableCard.new(id: id, fields: event.card_fields,
                                        model_id: event.model_id))
      }
    end

    def handle_model_named id, event
      update_model(id) { |model| model ||= CardFormat.new(id: id); model.set_name(event.name) }
    end

    attr_accessor :queue, :cards, :event_store, :_card_models, :_card_model_ids, :_card_model_id_by_card, :_editable_cards
  end
 
  class EditableCard < Hamsterdam::Struct.define(:id, :fields, :model_id)
  end

  class CardFormat < Hamsterdam::Struct.define(:id, :name, :fields, :question_template, :answer_template)
    def fields
      super || Hamster.vector
    end

    def format_question_with card_fields
      format question_template, card_fields
    end
    def format_answer_with card_fields
      format answer_template, card_fields
    end

    private
    def format str, fields
      str.gsub(/{{\s*(\w+)\s}}/) { |m| fields.fetch($1) }
    end
  end
end
