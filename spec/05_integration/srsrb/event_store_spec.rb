require 'srsrb/event_store'
require 'lexical_uuid'
require 'hamsterdam'
require_relative 'event_store_examples'

module SRSRB
  describe EventStore do
    it_should_behave_like :EventStore do
      let (:event_store) { EventStore.new }
    end
  end
end
