require 'srsrb/models'
require 'lexical_uuid'
require 'fake_event_store'

module SRSRB
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
