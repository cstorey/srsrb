require 'srsrb/deck_view'
require 'srsrb/events'

require 'hamster/hash'
require 'lexical_uuid'

module SRSRB
  describe DeckViewModel do
    let (:event_store) { FakeEventStore.new }
    let (:deck) { DeckViewModel.new event_store }

    let (:card_id) { LexicalUUID.new }
    let (:card) { Card.new id: card_id, review_count: 0, due_date: 0 }
    let (:tomorrow) { 1 }
    let (:card_reviewed_event) { CardReviewed.new next_due_date: tomorrow }

    class FakeEventStore
      include RSpec::Matchers
      def subscribe block
        expect(block).to respond_to :call
        self.subscribe_callback = block
      end

      def record! id, event
        subscribe_callback.call id, event
      end

      private
      attr_accessor :subscribe_callback
    end

    describe "#next_card_upto" do
      before do
        deck.start!
      end

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
          event_store.record! card.id, card_reviewed_event
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

    describe "#card_models" do
      it "Returns the empty list by default" do
        expect(deck.card_models).to be_empty
      end
    end

    describe "#start!" do
      before do
        deck.enqueue_card(card)
        deck.start!
      end

      context "when receiving CardReviewed events" do
      it "should update the review count for each card_reviewed" do
        expect do
          event_store.record! card.id, card_reviewed_event
        end.to change { deck.card_for(card.id).review_count }.by(1)
      end

      it "should update the due-date for the card to that specified in the event" do
        next_due_date = 4
        expect do
          event_store.record! card.id, card_reviewed_event.set_next_due_date(next_due_date)
        end.to change { deck.card_for(card.id).due_date }.from(0).to(next_due_date)
      end
      end

      context "when receiving CardEdited events" do
        let (:id) { LexicalUUID.new }
        let (:model_id) { LexicalUUID.new }
        let (:card_fields) { { "word" => "fish", "meaning" => "wet thing", "sound" => "ffish" } }
        before do
          card_fields.each do |field, _|
            event_store.record! model_id, ModelFieldAdded.new(field: field)
          end

          event_store.record! model_id,
            ModelTemplatesChanged.new(question: '{{ word }}', answer: '{{ meaning }} {{ sound }}')

          event_store.record! id, CardModelChanged.new(model_id: model_id)
          event_store.record! id, CardEdited.new(card_fields: card_fields)
        end

        it "should add it to the current stack of cards" do
          expect(deck.card_for(id)).to be_kind_of Card
        end

        it "should preserve the question" do
          card = deck.card_for(id)
          expect(card.question).to be == "fish"
        end
        it "should preserve the answer" do
          expect(deck.card_for(id).answer).to be == "wet thing ffish"
        end

        it "should set the due-date to zero" do
          expect(deck.card_for(id).due_date).to be == 0
        end
        it "should set the card id" do
          expect(deck.card_for(id).id).to be == id
        end
      end

      context "when receiving ModelNamed events" do
        let (:id) { LexicalUUID.new }
        let (:name) { "Jim" }
        context "when we send one event" do
          before do
            event_store.record! id, ModelNamed.new(name: name)
          end
          it "should add the a model object to the set of known models" do
            expect(deck.card_models.size).to be == 1
          end

          it "should store the id" do
              expect(deck.card_models.first).to be == id
          end

          it "should add the name" do
              expect(deck.card_model(id).name).to be == name
          end
        end

        context "when we send two events" do
          before do
            event_store.record! id, ModelNamed.new(name: "Stuff")
            event_store.record! id, ModelNamed.new(name: name)
          end
          it "should add the a model object to the set of known models" do
            expect(deck.card_models.size).to be == 1
          end

          it "should store the id" do
              expect(deck.card_models.first).to be == id
          end

          it "should add the name" do
              expect(deck.card_model(id).name).to be == name
          end
        end

        context "when we send umpteen events" do
          it "should return them in order of creation" do
            ids = (0...10).map { LexicalUUID.new }

            ids.each do |id|
              event_store.record! id, ModelNamed.new(name: id.to_guid)
            end

            expect(deck.card_models.map(&:to_guid).to_a).to be == ids.map(&:to_guid)
          end
        end
      end

      context "when receiving ModelFieldAdded events" do
        let (:id) { LexicalUUID.new }

        it "should implicitly create the model" do
          expect do
            event_store.record! id, ModelFieldAdded.new(field: "bob")
          end.to change { deck.card_models.size }.by 1
        end

        it "should add it to the fields in the model" do
          event_store.record! id, ModelFieldAdded.new(field: "bob")
          expect(deck.card_model(id).fields).to have(1).items
          expect(deck.card_model(id).fields).to include("bob")
        end
      end
    end
  end

  describe Card do
    describe "#as_json" do
      let (:data) { Hash[id: 42, question: 'eh', answer: 'yiss', review_count: 42, due_date: 0] }
      let (:card) { Card.new data } 
      it "should return the fields as a json-compatible dictionary" do
        expect(card.as_json).to be == data
      end
    end
  end
end
