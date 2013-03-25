require 'srsrb/deck_view'

module SRSRB
  describe DeckViewModel do
    let (:deck) { DeckViewModel.new }

    let (:card_id) { 342 }
    let (:card) { mock :card, id: card_id }

    describe "#next_card" do
      context "when the deck is empty" do
        it "returns no cards" do
          expect(deck.next_card).to be_nil
        end
      end
      context "when we have added a card" do
        before do
          deck.enqueue_card(card)
        end
        it "gets the next question in the deck" do
          expect(deck.next_card).to be == card
        end

        it "returns nil once empty" do
          deck.next_card
          expect(deck.next_card).to be_nil
        end
      end
    end

    describe "#card_for" do
      context "when there is no card" do
        it "returns nil" do
          expect(deck.card_for(32)).to be_nil
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
  end
end
