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
    def reviews_app
      ReviewsApp.new deck, deck_reviews
    end
    def card_editor_app
      CardEditorApp.new deck, card_editing
    end
    def model_editor_app
      ModelEditorApp.new deck, model_editing
    end
    def system_test_hack_api
      SystemTestHackApi.new(nil, deck, card_editing, model_editing)
    end

    def app
      Rack::Cascade.new(
        [reviews_app, card_editor_app, model_editor_app, system_test_hack_api]
      ).into { |app|
        Rack::Session::Pool.new app, :key => 'rack.session',
                           #:domain => 'foo.com',
                           :path => '/',
                           :expire_after => 2592000, # In seconds
                           :secret => 'change_me'
      }
    end

    def assemble
      at_exit { shutdown }
      deck.start!
      models.start!
      app
    end

    def shutdown
      event_store.close
    end
  end
end

