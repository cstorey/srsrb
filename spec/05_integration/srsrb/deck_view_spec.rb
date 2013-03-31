require 'srsrb/deck_view'
require 'srsrb/events'

require 'hamster/hash'
require 'lexical_uuid'

module SRSRB
  describe DeckViewModel do
    let (:event_store) { FakeEventStore.new }
    let (:deck) { DeckViewModel.new event_store }

    let (:card_id) { LexicalUUID.new }
    let (:card) { Card.new id: card_id, review_count: 0 }

    class FakeEventStore
      include RSpec::Matchers
      def subscribe block
        expect(block).to respond_to :call
        self.subscribe_callback = block
      end

      attr_accessor :subscribe_callback
    end

    describe "#next_card_upto" do
      context "when the deck is empty" do
        it "returns no cards" do
          expect(deck.next_card_upto(0)).to be_nil
        end
      end
      context "when we have added a card" do
        before do
          deck.enqueue_card(card)
        end
        it "gets the next question in the deck" do
          expect(deck.next_card_upto(0)).to be == card
        end

        it "returns nil once empty" do
          deck.next_card_upto 0
          expect(deck.next_card_upto(0)).to be_nil
        end
      end
    end

    describe "#card_for" do
      context "when there is no card" do
        it "returns nil" do
          an_arbitrary_uuid = LexicalUUID.new
          expect(deck.card_for(an_arbitrary_uuid)).to be_nil
        end
      end
      context "when said card has been added" do
        before do
          deck.enqueue_card(card)
        end
        it "returns the card with the given id" do
          expect(deck.card_for(card_id)).to be == card
        end
      end
    end

    describe "#start!" do
      it "should subscribe to the event_store" do
        deck.start!
        expect(event_store.subscribe_callback).to respond_to :call
      end

      context "with fake event store" do
        let (:event_store) { FakeEventStore.new }
        let (:card_reviewed_event) { CardReviewed.new }
        it "should update the review count for each card_reviewed" do
          deck.enqueue_card(card)

          deck.start!

          expect do
            event_store.subscribe_callback.call card.id, card_reviewed_event
          end.to change { deck.card_for(card.id).review_count }.by(1)
        end
      end
    end
  end

  describe Card do
    describe "#as_json" do
      let (:data) { Hash[id: 42, question: 'eh', answer: 'yiss', review_count: 42] }
      let (:card) { Card.new data } 
      it "should return the fields as a json-compatible dictionary" do
        expect(card.as_json).to be == data
      end
    end
  end
end
