require 'hamster/vector'
require 'hamster/set'
require 'hamsterdam'

module SRSRB
  class EventStore
    def initialize
      self.events = Hamster.vector
      self.subscribers = Hamster.set
    end
    def record! stream_id, event
      self.events = events.add(Commit.new stream_id: stream_id, data: event)

      subscribers.each do |s|
        s.call stream_id, event
      end
    end

    def subscribe &block
      events.each do |commit|
        block.call commit.stream_id, commit.data
      end

      self.subscribers = subscribers.add block
    end

    def count
      events.size
    end

    private
    attr_accessor :events, :subscribers
  end

  Commit = Hamsterdam::Struct.define(:stream_id, :data)
end
