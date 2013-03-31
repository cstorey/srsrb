require 'srsrb/events'

module SRSRB
  class Decks
    def initialize event_store
      self.event_store = event_store
    end

    def score_card! card_id, score
      event_store.record! card_id, CardReviewed.new(score: score, next_due_date: 1)
    end

    private
    attr_accessor :event_store
  end
end
