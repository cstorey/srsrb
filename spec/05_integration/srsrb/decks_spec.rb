require 'srsrb/decks'
require 'lexical_uuid'

module SRSRB
  describe ReviewScoring do
    let (:event_store) { mock :event_store }
    let (:decks) { ReviewScoring.new event_store }
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
  end

  describe CardEditing do
    let (:event_store) { mock :event_store }
    let (:models) { mock :models }
    let (:a_model) { mock :model, fields: Hamster.set(*card_fields.keys) }
    let (:decks) { CardEditing.new event_store, models }
    let (:card_id) { LexicalUUID.new }


    describe "#set_model_for_card!" do
      let (:card_id) { LexicalUUID.new }
      let (:new_model_id) { LexicalUUID.new }
      it "should record the change in the event store" do
        event_store.should_receive(:record!).with(card_id, CardModelChanged.new(model_id: new_model_id))
        decks.set_model_for_card! card_id, new_model_id
      end
    end

    describe "#add_or_edit_card!" do
      let (:card_id) { LexicalUUID.new }
      let (:model_id) { LexicalUUID.new }
      let (:card_fields) { { "stuff" => "things", "gubbins" => "cheese" } }

      before do
        event_store.as_null_object
        models.stub(:fetch).with(model_id).and_return(a_model)
        decks.set_model_for_card! card_id, model_id
      end

      it "should record the score, and card in the event store" do
        event_store.should_receive(:record!).with(card_id, CardEdited.new(card_fields: card_fields))
        decks.add_or_edit_card! card_id, card_fields
      end

      it "should fail if the card is missing a field" do
        card_fields.delete('stuff')
        expect do
          decks.add_or_edit_card! card_id, card_fields
        end.to raise_error(FieldMissingException)
      end
    end
  end

  describe Decks do
    let (:event_store) { mock :event_store }
    let (:models) { mock :models }
    let (:a_model) { mock :model, fields: Hamster.set(*card_fields.keys) }
    let (:decks) { Decks.new event_store, models }
    let (:card_id) { LexicalUUID.new }


    let (:model_id) { LexicalUUID.new }
    let (:model_name) { "my lovely words" }

    # Model operations. 
    describe "#name_model!" do
      it "should emit an even stating the model has been named" do
        event_store.should_receive(:record!).with(model_id, ModelNamed.new(name: model_name))
        decks.name_model! model_id, model_name
      end
      it "should disallow duplicate names"
    end

    describe "#edit_model_templates!" do
      it "should emit an even stating the templates have changed" do
        q_template = 'question'
        a_template = 'answer'
        event_store.should_receive(:record!).
          with(model_id, ModelTemplatesChanged.new(question: q_template, answer: a_template))
        decks.edit_model_templates! model_id, q_template, a_template
      end
      it "should maybe validate the templates are valid liquid templates"
    end

    describe "#add_model_field!" do
      let (:card_fields) { { "stuff" => "things", "gubbins" => "cheese" } }
      let (:name) { 'stuff' }

      before do
        models.stub(:fetch).with(model_id).and_return(a_model)
        a_model.stub(:add_field).with(name).and_return(:modified_model)
      end

      it "should emit an event stating the templates have changed" do
        event_store.should_receive(:record!).
          with model_id, ModelFieldAdded.new(field: name)
        decks.add_model_field! model_id, name
      end

      it "should emit an event stating the templates have changed" do
        event_store.should_receive(:record!).
          with model_id, ModelFieldAdded.new(field: name)
        decks.add_model_field! model_id, name
      end
    end
  end

  describe Models do
    describe "#fetch" do
      let (:event_store) { FakeEventStore.new }
      let (:models) { Models.new event_store }
      let (:model_id) { LexicalUUID.new }

      before :each do
        models.start!
        events.each do |evt|
          event_store.record! model_id, evt
        end
      end
      context "with no events" do
        let (:events) { [] }
        it "should return no models" do
          expect(models.fetch(model_id)).to be == nil
        end
      end

      context "with a single add field event" do
        let (:events) { [ModelFieldAdded.new(field: 'foo')] }
        it "should return a single model" do
          expect(models.fetch(model_id).fields).to have(1).items
        end

        it "should record the field name" do
          expect(models.fetch(model_id).fields).to include('foo')
        end
      end
    end
  end
end
