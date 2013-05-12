require 'srsrb/card_editing'

module SRSRB
  describe CardEditing do
    let (:event_store) { mock :event_store }
    let (:models) { mock :models }
    let (:a_model) { mock :model, fields: Hamster.set(*card_fields.keys) }
    let (:decks) { CardEditing.new event_store, models }
    let (:card_id) { LexicalUUID.new }

    AnEvent = Hamsterdam::Struct.define(:data)

    let (:previous_events) { [] }
    before do
      previous_events.inject(event_store.stub(:events_for_stream).with(card_id)) do |stub, (event, vers)|
        stub.and_yield(event, vers)
      end
    end

    describe "#add_or_edit_card!" do
      let (:card_id) { LexicalUUID.new }
      let (:model_id) { LexicalUUID.new }
      let (:card_fields) { { "stuff" => "things", "gubbins" => "cheese" } }

      before do
        event_store.as_null_object
        models.stub(:fetch).with(model_id).and_return(a_model)
      end

      it "should record the score, and card in the event store" do
        event_store.should_receive(:record!).
          with(card_id, 
               CardEdited.new(card_fields: Hamster.hash(card_fields), model_id: model_id),
               nil)
        decks.add_or_edit_card! card_id, model_id, card_fields
      end

      it "should fail if the card is missing a field" do
        card_fields.delete('stuff')
        expect do
          decks.add_or_edit_card! card_id, model_id, card_fields
        end.to raise_error(FieldMissingException)
      end

      it "should fail if the card is missing a field" do
        card_fields.delete('stuff')
        expect do
          decks.add_or_edit_card! card_id, model_id, card_fields
        end.to raise_error /stuff/
      end

      context "with previous events" do
        let (:previous_events) { [[AnEvent.new, 42]] }

        it "should use the most recent version" do
          event_store.should_receive(:record!).
            with(card_id, an_instance_of(CardEdited), 42)
          decks.add_or_edit_card! card_id, model_id, card_fields
        end
      end
    end
  end
end
