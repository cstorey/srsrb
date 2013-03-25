require 'srsrb/deck_view'

module SRSRB
  describe DeckViewModel do
    let (:deck) { DeckViewModel.new }
    describe "#next_card" do
      context "when the deck is empty" do
        it "returns no cards" do
          expect(deck.next_card).to be_nil
        end
      end
      context "when we have added a card" do
        let (:card) { mock :card }
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
  end
end
