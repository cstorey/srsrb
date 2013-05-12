require 'srsrb/decks'
require 'lexical_uuid'
require 'fake_event_store'

module SRSRB

  describe CardEditing do
    let (:event_store) { mock :event_store }
    let (:models) { mock :models }
    let (:a_model) { mock :model, fields: Hamster.set(*card_fields.keys) }
    let (:decks) { CardEditing.new event_store, models }
    let (:card_id) { LexicalUUID.new }

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

  describe ModelEditing do
    let (:event_store) { mock :event_store }
    let (:a_model) { mock :model, fields: Hamster.set(*card_fields.keys) }
    let (:decks) { ModelEditing.new event_store }
    let (:card_id) { LexicalUUID.new }


    let (:model_id) { LexicalUUID.new }
    let (:model_name) { "my lovely words" }

    let (:previous_events) { [] }
    before do
      previous_events.inject(event_store.stub(:events_for_stream).with(model_id)) do |stub, (event, vers)|
        stub.and_yield(event, vers)
      end
    end

    # Model operations. 
    describe "#name_model!" do
      it "should emit an even stating the model has been named" do
        event_store.should_receive(:record!).with(model_id, ModelNamed.new(name: model_name), nil)
        decks.name_model! model_id, model_name
      end
      it "should disallow duplicate names"

      context "with previous events" do
        let (:previous_events) { [[AnEvent.new, 42]] }

        it "should use the correct version" do
          event_store.should_receive(:record!).with(model_id, ModelNamed.new(name: model_name), 42)
          decks.name_model! model_id, model_name
        end
      end
    end

    describe "#edit_model_templates!" do
      let (:q_template) { 'question' }
      let (:a_template) { 'answer' }

      it "should emit an even stating the templates have changed" do
        event_store.should_receive(:record!).
          with(model_id, ModelTemplatesChanged.new(question: q_template, answer: a_template), nil)
        decks.edit_model_templates! model_id, q_template, a_template
      end
      context "with previous events" do
        let (:previous_events) { [[AnEvent.new, 42]] }

        it "should use the correct version" do
          event_store.should_receive(:record!).
            with(model_id, ModelTemplatesChanged.new(question: q_template, answer: a_template), 42)

          decks.edit_model_templates! model_id, q_template, a_template
        end
      end
      it "should maybe validate the templates are valid liquid templates"
    end

    describe "#add_model_field!" do
      let (:card_fields) { { "stuff" => "things", "gubbins" => "cheese" } }
      let (:name) { 'stuff' }
      before do
        a_model.stub(:add_field).with(name).and_return(:modified_model)
      end

      it "should emit an event stating the templates have changed" do
        event_store.should_receive(:record!).
          with model_id, ModelFieldAdded.new(field: name), nil
        decks.add_model_field! model_id, name
      end

      context "with previous events" do
        let (:previous_events) { [[AnEvent.new, 42]] }
        it "should use the current card version" do
          event_store.should_receive(:record!).
            with model_id, ModelFieldAdded.new(field: name), 42
          decks.add_model_field! model_id, name
        end
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
