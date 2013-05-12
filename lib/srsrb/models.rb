require 'srsrb/events'
require 'hamster/hash'
require 'atomic'

module SRSRB
  class Models
    def initialize event_store
      self.event_store = event_store
      self.models = Atomic.new Hamster.hash
    end

    def start!
      event_store.subscribe self
    end

    def fetch id
      models.get[id]
    end

    def handle_event id, event, _version
      return unless event.kind_of? ModelFieldAdded
      models.update do |models|
        models.fetch(id) { CardModel.new(fields: Hamster.set) }.
        into { |model| model.set_fields model.fields.add(event.field) }.
        into { |model| models.put(id, model) }
      end
    end

    private
    attr_accessor :event_store, :models
  end
  class CardModel < Hamsterdam::Struct.define :fields; end
end
