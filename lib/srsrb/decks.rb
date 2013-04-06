require 'srsrb/events'
require 'hamster/hash'

module SRSRB
  class Decks
    def initialize event_store
      self.event_store = event_store
      self.next_due_dates = Hamster.hash
      self.intervals = Hamster.hash
      self.model_ids_by_card = Hamster.hash
    end

    def score_card! card_id, score
      prev_due_date = next_due_dates.fetch(card_id, 0)

      if good? score
        prev_interval = intervals.fetch(card_id, 0)
        interval = [prev_interval * 2, 1].max
      elsif poor? score
        prev_interval = intervals.fetch(card_id, 0)
        interval = [prev_interval, 1].max
      else
        interval = 0
      end

      next_due_date = prev_due_date + interval

      self.next_due_dates = next_due_dates.put(card_id, next_due_date)
      self.intervals = intervals.put(card_id, interval)

      event_store.record! card_id, CardReviewed.new(score: score, next_due_date: next_due_date)
    end

    def add_or_edit_card! id, data
      event_store.record! id, CardEdited.new(card_fields: data)
    end

    def set_model_for_card! card_id, model_id
      event_store.record! card_id, CardModelChanged.new(model_id: model_id)
      self.model_ids_by_card = model_ids_by_card.put(card_id, model_id)
    end

    # Model operations
    def name_model! id, name
      event_store.record! id, ModelNamed.new(name: name)
    end

    def edit_model_templates! id, question, answer
      event_store.record! id, ModelTemplatesChanged.new(question: question, answer: answer)
    end

    def add_model_field! id, name
      event_store.record! id, ModelFieldAdded.new(field: name)
    end

    private

    def good? score
      score == :good
    end

    def poor? score
      score == :poor
    end
    attr_accessor :event_store, :next_due_dates, :intervals, :model_ids_by_card, :fields_by_model
  end
end
