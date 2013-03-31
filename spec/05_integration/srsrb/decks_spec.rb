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

      it "should increment spacing interval by a factor of two each time" do
        score = :good
        next_due_dates = []

        event_store.stub(:record!) do |id, event|
          next_due_dates << event.next_due_date
        end

        4.times { decks.score_card! card_id, score }

        expect(next_due_dates).to be == [1, 3, 7, 15]
      end

      it "should reset the intervals when a card is failed" do
        scores = [:good, :good, :fail, :good]
        next_due_dates = []

        event_store.stub(:record!) do |id, event|
          next_due_dates << event.next_due_date
        end

        scores.each { |score| decks.score_card! card_id, score }

        expect(next_due_dates).to be == [1, 3, 3, 4]
      end

    end
  end
end
