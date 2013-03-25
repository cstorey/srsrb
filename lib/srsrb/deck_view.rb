require 'hamsterdam'
require 'hamster/queue'
require 'hamster/hash'

module SRSRB
  class DeckViewModel
    def initialize
      self.queue = Hamster.queue
      self.cards = Hamster.hash
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
    attr_accessor :queue, :cards
  end

  Card = Hamsterdam::Struct.define(:id, :question, :answer)
  class Card
  end
end
