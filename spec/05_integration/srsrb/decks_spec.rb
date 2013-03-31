require 'srsrb/decks'
require 'lexical_uuid'

module SRSRB
  describe Decks do
    let (:event_store) { mock :event_store }
    let (:decks) { Decks.new event_store }
    let (:card_id) { LexicalUUID.new }

    describe "#score_card!" do
      it "should record the score, and card in the event store" do
        event_store.should_receive(:record!).with(card_id, an_instance_of(CardReviewed))
        decks.score_card! card_id, :good
      end

      it "should include the score in the persisted event" do
        score = :good

        event_store.stub(:record!) do |id, event|
          expect(event.score).to be == score
        end

        decks.score_card! card_id, score
      end

      it "should include the score in the persisted event" do
        score = :good

        event_store.stub(:record!) do |id, event|
          expect(event.next_due_date).to be == 1
        end

        decks.score_card! card_id, score
      end

      def next_due_dates_of scores
        next_due_dates = []
        event_store.stub(:record!) do |id, event|
          next_due_dates << event.next_due_date
        end

        scores.each { |score| decks.score_card! card_id, score }

        next_due_dates
      end

      it "should increment spacing interval by a factor of two each time" do
        expect(next_due_dates_of [:good] * 4).to be == [1, 3, 7, 15]
      end

      it "should reset the intervals when a card is failed" do
        expect(next_due_dates_of [:good, :good, :fail, :good]).to be == [1, 3, 3, 4]
      end

      it "should re-use the same interval when the card is scored as poor" do
        expect(next_due_dates_of [:good, :good, :poor, :poor]).to be == [1, 3, 5, 7]
      end
      it "should use a minimum interval of 1 when the card is initially scored as poor" do
        expect(next_due_dates_of [:poor, :good, :good, :good]).to be == [1, 3, 7, 15]
      end
      it "should use a minimum interval of 1 when the card is scored failed scored as poor" do
        expect(next_due_dates_of [:good, :good, :fail, :poor]).to be == [1, 3, 3, 4]
      end
    end

    describe "#add_or_edit_card!" do
      let (:card_id) { LexicalUUID.new }
      let (:card_fields) { { "stuff" => "things", "gubbins" => "cheese" } }

      it "should record the score, and card in the event store" do
        event_store.should_receive(:record!).with(card_id, CardEdited.new(card_fields: card_fields))
        decks.add_or_edit_card! card_id, card_fields
      end

      it "should validate the card data against the card's model"
    end
  end
end
