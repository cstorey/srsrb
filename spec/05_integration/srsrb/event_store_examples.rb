require 'srsrb/errors'

module SRSRB
  shared_examples_for :EventStore do
    AnEvent = Hamsterdam::Struct.define(:data)
    let (:a_stream) { LexicalUUID.new }
    let (:some_event) { AnEvent.new data: 42 }
    describe "#record!" do
      it "should increase the number of recorded events by one" do
        expect do
          event_store.record! a_stream, some_event
        end.to change { event_store.count }.by(1)
      end

      it "should return an integer version" do
        version = event_store.record! a_stream, some_event
        expect(version).to be_kind_of Integer
      end

      it "should return a unique event id" do
        version0 = event_store.record! a_stream, some_event
        version1 = event_store.record! a_stream, some_event, version0
        expect(version0).to be < version1
      end

      it "should abort iff we pass the wrong version" do
        version0 = event_store.record! a_stream, some_event
        version1 = event_store.record! a_stream, some_event, version0
        expect  do
          event_store.record! a_stream, some_event, version0
        end.to raise_error(WrongEventVersionError)
      end
      context "when we have fixed all of the clients" do
        it "should only accept a nil version for a new stream"
      end
    end

    describe "#subscribe" do
      # Danger will robinson! Mutable state!
      let (:callback_args) { [] }
      let (:listener) { mock :event_listener }
      let (:events) { (0...10).map { |n| AnEvent.new data: n } }
      it "should iterate over all events added to the store in turn" do
        expected_yield_args = events.map { |e| [a_stream, e] }

        events.each do |e|
          event_store.record! a_stream, e
        end

        events.each do |evt|
          listener.should_receive(:handle_event).with(a_stream, evt)
        end

        event_store.subscribe listener
      end

      it "should fire the block when new events arrive" do
        event_store.subscribe listener

        listener.should_receive(:handle_event).with(a_stream, some_event)

        event_store.record! a_stream, some_event
      end

      it "should explicitly support multiple subscribers"
    end
  end
end
