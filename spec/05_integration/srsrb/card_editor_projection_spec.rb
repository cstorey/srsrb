require 'srsrb/card_editor_projection'
require 'srsrb/events'

require 'hamster/hash'
require 'lexical_uuid'
require 'fake_event_store'


module SRSRB
  describe CardEditorProjection do
    let (:event_store) { FakeEventStore.new }
    let (:deck) { described_class.new event_store }

    let (:card_id) { LexicalUUID.new }
    let (:card) { Card.new id: card_id, review_count: 0, due_date: 0 }
    let (:tomorrow) { 1 }


    describe "#card_models" do
      it "Returns the empty list by default" do
        expect(deck.card_models).to be_empty
      end
    end

    describe "#all_cards" do
      it "returns an empty collection by default" do
        expect(deck.all_cards).to be_empty
      end
    end

    describe "#editable_card_for" do
      let (:an_id) { LexicalUUID.new }
      it "returns nil with no cards" do
        expect(deck.editable_card_for an_id).to be_nil
      end
    end

    describe "#start!" do
      before do
        deck.start!
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

        it "should be included in all_cards" do
          pp card_ids: deck.all_cards.map(&:id).map(&:to_guid), model: model_id.to_guid, card: id.to_guid
          known_cards = deck.all_cards.map(&:id).to_set
          expect(known_cards).to have(1).items
          expect(known_cards).to include(id)
        end

        context "#editable_card_for" do
          it "should record an editable card the given id" do
            expect(deck.editable_card_for(id).id).to be == id
          end
          it "should record an editable card the given fields" do
            expect(deck.editable_card_for(id).fields).to be == card_fields
          end
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
end
