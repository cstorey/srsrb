require 'srsrb/errors'
require 'hamster/vector'
require 'hamster/set'
require 'hamsterdam'

module SRSRB

  class EventStore
    UNSPECIFIED = Object.new
    def initialize
      self.events = Hamster.vector
      self.subscribers = Hamster.set
    end
    def record! stream_id, event, expected_version=UNSPECIFIED
      raise WrongEventVersionError if expected_version != UNSPECIFIED && current_version != expected_version

      $stderr.puts "No version passed to #{self.class.name}#record! at #{caller[0]}" if expected_version == UNSPECIFIED

      commit = Commit.new stream_id: stream_id, data: event
      self.events = events.add(commit)

      subscribers.each do |listener|
        listener.handle_event stream_id, event
      end
      current_version
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

    def current_version
      events.size
    end
    attr_accessor :events, :subscribers
  end

  Commit = Hamsterdam::Struct.define(:stream_id, :data)
end
