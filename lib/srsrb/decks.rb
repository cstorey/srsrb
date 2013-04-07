require 'srsrb/events'
require 'hamster/hash'

# TODO: Split according to usage:
#
# CardEditorApp	decks.add_or_edit_card
# CardEditorApp	decks.set_model_for_card
#
# ModelEditorApp	decks.add_model_field
# ModelEditorApp	decks.edit_model_templates
# ModelEditorApp	decks.name_model
#
# ReviewsApp	decks.score_card

module SRSRB
  class FieldMissingException < RuntimeError; end
  class ReviewScoring
    def initialize event_store
      self.event_store = event_store
      self.next_due_dates = Hamster.hash
      self.intervals = Hamster.hash
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

    private
    attr_accessor :event_store, :next_due_dates, :intervals

    def good? score
      score == :good
    end

    def poor? score
      score == :poor
    end
  end

  class Decks
    def initialize event_store, models
      self.event_store = event_store
      self.next_due_dates = Hamster.hash
      self.intervals = Hamster.hash
      self.model_ids_by_card = Hamster.hash
      self.models = models
    end

    def add_or_edit_card! id, data
      model_id = model_ids_by_card.fetch(id) { fail "Missing model for card #{id.to_guid} " }
      expected_fields = models.fetch(model_id).fields
      missing_fields = (expected_fields - data.keys)
      raise FieldMissingException if not missing_fields.empty?

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
      old_model_fields = models.fetch(id) { Hamster.set }
    end

    private
    def fields_for_model model_id
      fields_by_model.fetch(model_id) { fail "Missing fields for model #{model_id.to_guid}" }
    end

    attr_accessor :event_store, :next_due_dates, :intervals, :model_ids_by_card, :models
  end

  class Models
    def initialize event_store
      self.event_store = event_store
      self.models = Hamster.hash
    end

    def start!
      event_store.subscribe method(:handle_event)
    end

    def fetch id
      models[id]
    end

    private

    def handle_event id, event
      return unless event.kind_of? ModelFieldAdded
      model = models[id] || CardModel.new(fields: Hamster.set)
      model = model.set_fields model.fields.add(event.field)
      self.models = models.put(id, model)
    end
    attr_accessor :event_store, :models
  end
  class CardModel < Hamsterdam::Struct.define :fields; end
end
