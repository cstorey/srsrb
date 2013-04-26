require 'srsrb/leveldb_event_store'
require 'lexical_uuid'
require 'hamsterdam'
require 'tempfile'
require_relative 'event_store_examples'

module SRSRB
  describe LevelDbEventStore do
    it_should_behave_like :EventStore do
      let (:dbpath) { Dir.mktmpdir }
      let (:event_store) { LevelDbEventStore.new dbpath }

      after do
        event_store.close
        FileUtils.rm_rf dbpath
      end

      # BER encoding is lexicographically sorted upto 2**14; but not after that.
      context "with large numbers of events when nevents > (2**14)" do
        before { pending "Slow tests" }
        let (:n) { 2**14 + 5 }
        let (:id) { LexicalUUID.new }
        before :each do
          version = nil
          n.times do
            version = event_store.record! id, id, version
          end
        end
        it "#count returns the correct number of events" do
          expect(event_store.count).to be == n
        end

        it "subsequent subscribers receive the correct number of events" do
          subscriber = mock :subscriber
          subscriber.should_receive(:handle_event).exactly(n).times
          event_store.subscribe subscriber
        end
      end
    end
  end
end
