require 'hamsterdam'
require 'hamster/queue'
require 'hamster/hash'

module SRSRB
  class DeckViewModel
    def initialize event_store
      self.cards = Hamster.hash
      self.event_store = event_store
      self._card_models = Hamster.hash
    end

    def start!
      event_store.subscribe method :handle_event
    end

    def next_card_upto time
      return if cards.empty?
      next_card = cards.values.sort_by { |c| c.due_date }.first
      next_card if next_card.due_date <= time
    end

    def card_for id
      cards[id]
    end

    def enqueue_card card
      self.cards = cards.put(card.id, card)
    end

    def card_models
      _card_models.values
    end

    private
    def handle_event id, event
      case event
        when CardReviewed then handle_card_reviewed id, event
        when CardEdited then handle_card_edited id, event
        when ModelNamed then handle_model_named id, event
      end
    end

    def handle_card_reviewed id, event
      card0 = cards.fetch(id)
      card1 = card0.
        set_review_count(card0.review_count.to_i.succ).
        set_due_date(event.next_due_date)

      self.cards = cards.put(id, card1)
    end

    def handle_card_edited id, event
      card = Card.new id: id,
          question: event.card_fields.fetch('question'), 
          answer: event.card_fields.fetch('answer')

      self.cards = cards.put(id, card)
    end

    def handle_model_named id, event
      self._card_models = _card_models.put id, CardModel.new(id: id, name: event.name)
    end

    attr_accessor :queue, :cards, :event_store, :_card_models
  end

  class Card < Hamsterdam::Struct.define(:id, :question, :answer, :review_count, :due_date)
    def as_json
      Hash.new.tap do |h|
        self.class.field_names.each do |f|
          h[f] = public_send f
        end
      end
    end

    def due_date
      super || 0
    end
  end
  class CardModel < Hamsterdam::Struct.define(:id, :name)
  end
end
