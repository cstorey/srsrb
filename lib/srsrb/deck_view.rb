require 'hamsterdam'
require 'hamster/queue'
require 'hamster/hash'

module SRSRB
  class DeckViewModel
    def initialize event_store
      self.queue = Hamster.queue
      self.cards = Hamster.hash
      self.event_store = event_store
    end

    def start!
      event_store.subscribe method :handle_event
    end

    def next_card
      q0 = queue
      self.queue = queue.dequeue
      q0.head
    end

    def card_for id
      cards[id]
    end

    def enqueue_card card
      self.queue = queue.enqueue(card)
      self.cards = cards.put(card.id, card)
    end

    private
    def handle_event id, event
      card0 = cards.fetch(id)
      card1 = card0.set_review_count(card0.review_count.succ)
      self.cards = cards.put(id, card1)
    end
    attr_accessor :queue, :cards, :event_store
  end

  Card = Hamsterdam::Struct.define(:id, :question, :answer, :review_count)
  class Card
    def as_json
      Hash.new.tap do |h|
        self.class.field_names.each do |f|
          h[f] = public_send f
        end
      end
    end
  end
end
