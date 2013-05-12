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
