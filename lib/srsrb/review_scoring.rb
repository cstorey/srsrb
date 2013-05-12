module SRSRB
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
end
