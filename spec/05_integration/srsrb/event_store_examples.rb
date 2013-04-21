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
        end.to change { event_store.count }.from(0).to(1)
      end

      it "should return an integer version" do
        version = event_store.record! a_stream, some_event
        expect(version).to be_kind_of Integer
      end

      it "should return a unique event id" do
        version0 = event_store.record! a_stream, some_event, nil
        version1 = event_store.record! a_stream, some_event, version0
        expect(version0).to be < version1
      end

      it "should abort iff we pass the wrong version" do
        version0 = event_store.record! a_stream, some_event, nil
        version1 = event_store.record! a_stream, some_event, version0
        expect  do
          event_store.record! a_stream, some_event, version0
        end.to raise_error(WrongEventVersionError)
      end

      it "should only accept a nil version for a new stream" do
        version0 = event_store.record! a_stream, some_event, nil
        version1 = event_store.record! a_stream, some_event, version0
        expect  do
          event_store.record! a_stream, some_event, nil
        end.to raise_error(WrongEventVersionError)
      end

      it "should support versioning per-stream" do
        stream0 = LexicalUUID.new
        stream1 = LexicalUUID.new
        version0 = event_store.record! stream0, some_event, nil
        version1 = event_store.record! stream1, some_event, nil

        version0 = event_store.record! stream0, some_event, version0
        version1 = event_store.record! stream1, some_event, version1
      end
    end

    describe "#subscribe" do
      # Danger will robinson! Mutable state!
      let (:callback_args) { [] }
      let (:listener) { mock :event_listener }
      let (:events) { (0...10).map { |n| AnEvent.new data: n } }
      it "should iterate over all events added to the store in turn" do
        expected_yield_args = events.map { |e| [a_stream, e] }

        version = nil
        versions = []
        events.each do |e|
          version = event_store.record! a_stream, e, version
          versions << version
        end

        events.zip(versions).each do |(evt, version)|
          listener.should_receive(:handle_event).with(a_stream, evt, version)
        end

        event_store.subscribe listener
      end

      it "should fire the block when new events arrive" do
        event_store.subscribe listener

        listener.should_receive(:handle_event).with(a_stream, some_event, anything)

        event_store.record! a_stream, some_event
      end

      it "should notify the handler of the version for each event" do
        event_store.subscribe listener

        emitted_version = nil
        listener.stub(:handle_event) do |_, _, v|
          emitted_version = v
        end

        recorded_version = event_store.record! a_stream, some_event
        expect(emitted_version).to be == recorded_version
      end

      it "should explicitly support multiple subscribers"
    end

    describe "#events_for_stream" do
      it "should yield all of the current events for a given stream" do
        version = event_store.record! a_stream, some_event
        expect do |p|
          event_store.events_for_stream a_stream, &p
        end.to yield_successive_args([some_event, version])
      end

      it "should yield only the current events for a given stream" do
        event_store.record! LexicalUUID.new, some_event
        expect do |p|
          event_store.events_for_stream a_stream, &p
        end.to yield_successive_args()
      end

    end
  end

end
