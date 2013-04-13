require 'srsrb/leveldb_event_store'
require 'lexical_uuid'
require 'hamsterdam'
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
    end
  end
end
