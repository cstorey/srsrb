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

      subscribers.each do |listener|
        listener.handle_event stream_id, event
      end
    end

    def subscribe listener
      events.each do |commit|
        listener.handle_event commit.stream_id, commit.data
      end

      self.subscribers = subscribers.add listener
    end

    def count
      events.size
    end

    private
    attr_accessor :events, :subscribers
  end

  Commit = Hamsterdam::Struct.define(:stream_id, :data)
end
