require 'srsrb/review_projection'
require 'srsrb/events'

require 'hamster/hash'
require 'lexical_uuid'
require 'fake_event_store'

module SRSRB
  describe ReviewProjection do
    let (:event_store) { FakeEventStore.new }
    let (:deck) { described_class.new event_store }

    let (:card_id) { LexicalUUID.new }
    let (:card) { Card.new id: card_id, review_count: 0, due_date: 0 }
    let (:tomorrow) { 1 }
    let (:card_reviewed_event) { CardReviewed.new next_due_date: tomorrow }

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

    describe "#all_cards" do
      it "returns an empty collection by default" do
        expect(deck.all_cards).to be_empty
      end
    end

    describe "#start!" do
      before do
        deck.start!
      end

      context "when receiving CardReviewed events" do
        before do
          deck.enqueue_card(card)
        end
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
        let (:question_template) { '{{ word}}' }
        let (:answer_template) { '{{ meaning }} {{ sound  }}' }
        before do
          card_fields.each do |field, _|
            event_store.record! model_id, ModelFieldAdded.new(field: field)
          end

          event_store.record! model_id,
            ModelTemplatesChanged.new(question: question_template, answer: answer_template)

          event_store.record! id, CardEdited.new(card_fields: card_fields, model_id: model_id)
        end

        it "should add it to the current stack of cards" do
          expect(deck.card_for(id)).to be_kind_of Card
        end

        it "should be included in all_cards" do
          known_cards = deck.all_cards.map(&:id).to_set
          expect(known_cards).to have(1).items
          expect(known_cards).to include(id)
        end

        it "updates should be reflected in #all_cards"

        it "should preserve the question" do
          card = deck.card_for(id)
          expect(card.question).to be == "fish"
        end
        it "should preserve the answer" do
          expect(deck.card_for(id).answer).to be == "wet thing ffish"
        end

        context "with a template with an unknown field" do
          let (:question_template) { " {{ random }} " }
          it "should render the missing field name" do
            card = deck.card_for(id)
            expect(card.question).to match /random/
          end
        end

        it "should set the due-date to zero" do
          expect(deck.card_for(id).due_date).to be == 0
        end
        it "should set the card id" do
          expect(deck.card_for(id).id).to be == id
        end
        context "when there are multiple models" do
          it "should render the card with the correct model"
        end
      end

      context "when receiving ModelTemplatesChanged events" do
        let (:id) { LexicalUUID.new }
        let (:model_id) { LexicalUUID.new }
        let (:card_fields) { { "word" => "fish", "meaning" => "wet thing", "sound" => "ffish" } }
        before do
          card_fields.each do |field, _|
            event_store.record! model_id, ModelFieldAdded.new(field: field)
          end
        end
        it "should re-render cards with the given card model with the new template"
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
