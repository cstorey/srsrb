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

    describe "#each_event" do
      it "should iterate over all events added to the store in turn" do
        events = (0...10).map { |n| AnEvent.new data: n } 
        events.each do |e|
          event_store.record! a_stream, e
        end

        expected_yield_args = events.map { |e| [a_stream, e] }
        expect do |block|
          event_store.each_event &block
        end.to yield_successive_args(*expected_yield_args)
      end
    end
  end
end
