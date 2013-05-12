require 'srsrb/review_scoring'

module SRSRB
  describe ReviewScoring do
    let (:event_store) { mock :event_store }
    let (:decks) { ReviewScoring.new event_store }
    let (:card_id) { LexicalUUID.new }

    describe "#score_card!" do
      let (:previous_reviews) { [] }
      before do
        m = event_store.stub(:events_for_stream).with(card_id)
        previous_reviews.each_with_index do |ev, idx|
          m.and_yield(ev, idx)
        end
      end

      it "should record the score, and card in the event store" do
        event_store.should_receive(:record!).with(card_id, an_instance_of(CardReviewed), nil)
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
        events = previous_reviews
        event_store.stub(:record!) do |id, event|
          events << event
          next_due_dates << event.next_due_date
        end

        event_store.stub(:events_for_stream) { |&p|
          events.each_with_index(&p)
        }

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

      def intervals_of scores
        intervals = []
        events = previous_reviews
        event_store.stub(:record!) do |id, event|
          events << event
          intervals << event.interval
        end

        event_store.stub(:events_for_stream) { |&p|
          events.each_with_index(&p)
        }

        scores.each { |score| decks.score_card! card_id, score }

        intervals
      end

      it "should increment spacing interval by a factor of two each time" do
        expect(intervals_of [:good] * 4).to be == [1, 2, 4, 8]
      end

      it "should reset the intervals when a card is failed" do
        expect(intervals_of [:good, :good, :fail, :good]).to be == [1, 2, 0, 1]
      end

      it "should re-use the same interval when the card is scored as poor" do
        expect(intervals_of [:good, :good, :poor, :poor]).to be == [1, 2, 2, 2]
      end
      it "should use a minimum interval of 1 when the card is initially scored as poor" do
        expect(intervals_of [:poor, :good, :good, :good]).to be == [1, 2, 4, 8]
      end

      it "should use a minimum interval of 1 when the card is scored failed scored as poor" do
        expect(intervals_of [:good, :good, :fail, :poor]).to be == [1, 2, 0, 1]
      end

      context "with some pre-existing reviews" do
        let (:previous_reviews) { [CardReviewed.new(next_due_date: 10, interval: 5)] }
        it "should carry on where it left off" do
          expect(next_due_dates_of [:good] * 4).to be == [20, 40, 80, 160]
        end

        it "should record changes with the previous stream version" do
          last_stream_id = previous_reviews.size-1
          event_store.should_receive(:record!).with(card_id, an_instance_of(CardReviewed), last_stream_id)
          decks.score_card! card_id, :good
        end
      end

      context "with some other things that happened to this card" do
        let (:previous_reviews) { [CardEdited.new()] * 4 }
        it "should just ignore them" do
          expect(next_due_dates_of [:good] * 4).to be == [1, 3, 7, 15]
        end

        it "should record the changed version" do
          last_stream_id = previous_reviews.size-1
          event_store.should_receive(:record!).with(card_id, an_instance_of(CardReviewed), last_stream_id)
          decks.score_card! card_id, :good
        end

      end
    end
  end
end
