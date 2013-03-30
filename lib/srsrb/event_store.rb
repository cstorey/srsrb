require 'hamster/vector'
require 'hamsterdam'

module SRSRB
  class EventStore
    def initialize
      self.events = Hamster.vector
    end
    def record! stream_id, event
      self.events = events.add(Commit.new stream_id: stream_id, data: event)
      pp added: event, events: events
    end

    def each_event &block
      events.each do |commit|
        pp a_commit: commit
        block.call commit.stream_id, commit.data
      end
    end

    def count
      events.size
    end

    private
    attr_accessor :events
  end

  Commit = Hamsterdam::Struct.define(:stream_id, :data)
end
