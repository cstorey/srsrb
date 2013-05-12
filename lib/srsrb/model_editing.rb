require 'srsrb/events'

module SRSRB
  class ModelEditing
    def initialize event_store
      self.event_store = event_store
    end


    # Model operations
    def name_model! id, name
      event_store.record! id, ModelNamed.new(name: name), version_of(id)
    end

    def edit_model_templates! id, question, answer
      event_store.record! id, ModelTemplatesChanged.new(question: question, answer: answer), version_of(id)
    end

    def add_model_field! id, name
      event_store.record! id, ModelFieldAdded.new(field: name), version_of(id)
    end

    private
    def events_for id
      event_store.to_enum(:events_for_stream, id).to_a
    end

    def version_of id
      version = events_for(id).map(&:last).last
    end

    attr_accessor :event_store
  end
end
