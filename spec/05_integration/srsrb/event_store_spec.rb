require 'srsrb/event_store'
require 'lexical_uuid'
require 'hamsterdam'

module SRSRB
  describe EventStore do
    AnEvent = Hamsterdam::Struct.define(:data)
    let (:event_store) { EventStore.new }
    let (:a_stream) { LexicalUUID.new }
    let (:some_event) { AnEvent.new data: 42 }
    describe "#record!" do
      it "should increase the number of recorded events by one" do
        expect do
          event_store.record! a_stream, some_event
        end.to change { event_store.count }.by(1)
      end

      it "should return the event id"
      it "should abort iff we pass the wrong version"
    end

    describe "#subscribe" do
      # Danger will robinson! Mutable state!
      let (:callback_args) { [] }
      let (:callback) { ->(stream, event) { callback_args << [stream, event] } }
      let (:events) { (0...10).map { |n| AnEvent.new data: n } }
      it "should iterate over all events added to the store in turn" do
        expected_yield_args = events.map { |e| [a_stream, e] }

        events.each do |e|
          event_store.record! a_stream, e
        end

        expect do |block|
          event_store.subscribe callback
        end.to change { callback_args }.from([]).to(expected_yield_args)
      end

      it "should fire the block when new events arrive" do
        event_store.subscribe callback

        expect do
          event_store.record! a_stream, some_event
        end.to change { callback_args }.from([]).to([[a_stream, some_event]])
      end

      it "should explicitly support multiple subscribers"
    end
  end
end
