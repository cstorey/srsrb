require 'srsrb/deck_view'
require 'srsrb/decks'
require 'srsrb/leveldb_event_store'
require 'srsrb/object_patch'
require 'srsrb/rackapp'

require 'lexical_uuid'

module SRSRB
  class Main
    def self.assemble
      self.new.assemble
    end

    def storedir
      ENV.fetch('EVENT_STOREDIR') { '/tmp/srsrb.events.%d.%s' % [Process.uid, LexicalUUID.new.to_guid] }
    end
    def event_store
      @event_store ||= LevelDbEventStore.new storedir
      #@event_store ||= EventStore.new
    end
    def models
      @models ||= Models.new event_store
    end
    def model_editing
      @model_editing ||= ModelEditing.new event_store
    end
    def deck_reviews
      @deck_reviews ||= ReviewScoring.new event_store
    end
    def card_editing
      @card_editing ||= CardEditing.new event_store, models
    end
    def deck
      @deck ||= DeckViewModel.new event_store
    end

    # We really want layered mixins for this.
    def app0
      ReviewsApp.new deck, deck_reviews
    end
    def app1
      CardEditorApp.new deck, card_editing, app0
    end
    def app2
      ModelEditorApp.new deck, model_editing, app1
    end
    def app3
      SystemTestHackApi.new(app2, deck, card_editing, model_editing)
    end

    def app4
      Rack::Session::Pool.new app3, :key => 'rack.session',
                           #:domain => 'foo.com',
                           :path => '/',
                           :expire_after => 2592000, # In seconds
                           :secret => 'change_me'
    end

    def assemble
      deck.start!
      models.start!
      app4
    end
  end
end

