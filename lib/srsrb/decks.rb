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
  class FieldMissingException < RuntimeError;
    def initialize got, missing
      @got = got
      @missing = missing
    end

    def message
      "Missing fields: #{missing.inspect}, got: #{got.inspect}"
    end

    attr_reader :missing, :got
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
      self.models = models
    end

    def add_or_edit_card! id, model_id, data
      card = get_card(id)
      expected_fields = models.fetch(model_id).fields
      missing_fields = (expected_fields - data.keys)
      raise FieldMissingException.new(data.keys, missing_fields) if not missing_fields.empty?

      event_store.record! id, 
        CardEdited.new(card_fields: Hamster.hash(data), model_id: model_id),
       card.version
    end

    private

    class Card < Hamsterdam::Struct.define :id, :version, :model_id, :event_store
      def apply event, version
        set_version(version)
      end
    end

    def get_card id
      event_store.to_enum(:events_for_stream, id).
        inject(Card.new id: id, event_store: event_store) { |card, (event, version)|
          card.apply(event, version)
      }
    end

    def version_of id
      get_card(id).version
    end
    attr_accessor :event_store, :models
  end

  class ModelEditing
    def initialize event_store
      self.event_store = event_store
    end


    # Model operations
    def name_model! id, name
      event_store.record! id, ModelNamed.new(name: name), version_of(id)
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
