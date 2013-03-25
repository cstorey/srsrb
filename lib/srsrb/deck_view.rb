require 'hamsterdam'

module SRSRB
  class DeckViewModel
    def initialize
      self.queue = Hamster.queue
    end
    def next_card
      q0 = queue
      self.queue = queue.dequeue
      q0.head
    end

    def enqueue_card card
      self.queue = queue.enqueue(card)
    end

    private
    attr_accessor :queue
  end

  Card = Hamsterdam::Struct.define(:id, :question, :answer)
  class Card
  end
end
