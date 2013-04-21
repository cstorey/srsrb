require 'srsrb/events'
require 'hamster/hash'
require 'atomic'

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
    end

    def score_card! card_id, score
      # If we do this inside the Atomic#update test-and-set loop, then because
      # the event store broadcasts updates to listeners synchronously
      # (including ourselves). So, it's best to trust (!) that the version
      # checks in the event store will catch any badness.

      card = get_card card_id
      card.score_as(score)
    end

    private

    def get_card card_id
      load_card_from_events card_id
    end

    def load_card_from_events card_id
      card = ReviewableCard.new(id: card_id, store: event_store, next_due_date: 0, interval: 0)
      event_store.events_for_stream card_id do |event, version|
        card = card.apply(event, version)
      end
      card
    end

    def update_card card_id
      cards.update do |cs|
        card = cs.fetch(card_id) {
          load_card_from_events card_id
        }
        card = yield card
        cs.put card_id, card
      end
    end

    attr_accessor :event_store, :cards
  end

  class ReviewableCard < Hamsterdam::Struct.define(:id, :version, :next_due_date, :interval, :store)
    def score_as score
      if good? score
        interval = [self.interval * 2, 1].max
      elsif poor? score
        interval = [self.interval, 1].max
      else
        interval = 0
      end

      next_due_date = self.next_due_date + interval
      event = CardReviewed.new score: score, next_due_date: next_due_date, interval: interval
      version = store.record! id, event, self.version
      self.set_interval(interval).set_next_due_date(next_due_date).set_version(version)
    end

    def apply event, new_version
      return self.set_version(new_version) if not event.kind_of? CardReviewed
      self.set_interval(event.interval).set_next_due_date(event.next_due_date).set_version(new_version)
    end

    private
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
      event_store.record! card_id, CardModelChanged.new(model_id: model_id), version_of(card_id)
      model_ids_by_card.update { |idx| idx.put(card_id, model_id) }
    end

    private
    def events_for id
      event_store.to_enum(:events_for_stream, id).to_a
    end

    def version_of id
      version = events_for(id).map(&:last).last
    end
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
      event_store.record! id, ModelTemplatesChanged.new(question: question, answer: answer), version_of(id)
    end

    def add_model_field! id, name
      event_store.record! id, ModelFieldAdded.new(field: name), version_of(id)
    end

    private
    def events_for id
      event_store.to_enum(:events_for_stream, id).to_a
    end

    def version_of id
      version = events_for(id).map(&:last).last
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

    def handle_event id, event, _version
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
