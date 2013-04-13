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
      self.next_due_dates = Atomic.new Hamster.hash
      self.intervals = Atomic.new Hamster.hash
    end

    def score_card! card_id, score
      prev_due_date = next_due_dates.get.fetch(card_id, 0)

      if good? score
        prev_interval = intervals.get.fetch(card_id, 0)
        interval = [prev_interval * 2, 1].max
      elsif poor? score
        prev_interval = intervals.get.fetch(card_id, 0)
        interval = [prev_interval, 1].max
      else
        interval = 0
      end

      next_due_date = prev_due_date + interval

      next_due_dates.update { |dates| dates.put(card_id, next_due_date) }
      intervals.update { |intervals| intervals.put(card_id, interval) }

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

  class CardEditing
    def initialize event_store, models
      self.event_store = event_store
      self.model_ids_by_card = Atomic.new Hamster.hash
      self.models = models
    end

    def add_or_edit_card! id, data
      model_id = model_ids_by_card.get.fetch(id) { fail "Missing model for card #{id.to_guid} " }
      expected_fields = models.fetch(model_id).fields
      missing_fields = (expected_fields - data.keys)
      raise FieldMissingException if not missing_fields.empty?

      event_store.record! id, CardEdited.new(card_fields: data)
    end

    def set_model_for_card! card_id, model_id
      event_store.record! card_id, CardModelChanged.new(model_id: model_id)
      model_ids_by_card.update { |idx| idx.put(card_id, model_id) }
    end

    private
    attr_accessor :event_store, :model_ids_by_card, :models
  end

  class ModelEditing
    def initialize event_store
      self.event_store = event_store
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

    attr_accessor :event_store
  end

  class Models
    def initialize event_store
      self.event_store = event_store
      self.models = Atomic.new Hamster.hash
    end

    def start!
      event_store.subscribe self
    end

    def fetch id
      models.get[id]
    end

    def handle_event id, event
      return unless event.kind_of? ModelFieldAdded
      models.update do |models|
        models.fetch(id) { CardModel.new(fields: Hamster.set) }.
        into { |model| model.set_fields model.fields.add(event.field) }.
        into { |model| models.put(id, model) }
      end
    end

    private
    attr_accessor :event_store, :models
  end
  class CardModel < Hamsterdam::Struct.define :fields; end
end
