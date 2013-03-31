require 'srsrb/events'
require 'hamster/hash'

module SRSRB
  class Decks
    def initialize event_store
      self.event_store = event_store
      self.next_due_dates = Hamster.hash
      self.intervals = Hamster.hash
    end

    def score_card! card_id, score
      prev_due_date = next_due_dates.fetch(card_id, 0)
      prev_interval = intervals.fetch(card_id, 0.5)

      interval = prev_interval * 2

      next_due_date = prev_due_date + interval

      pp card: card_id.to_s, prev_due_date: prev_due_date, next: next_due_date

      self.next_due_dates = next_due_dates.put(card_id, next_due_date)
      self.intervals = intervals.put(card_id, interval)

      event_store.record! card_id, CardReviewed.new(score: score, next_due_date: next_due_date)
    end

    private
    attr_accessor :event_store, :next_due_dates, :intervals
  end
end
