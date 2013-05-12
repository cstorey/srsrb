require 'srsrb/review_projection'
require 'srsrb/card_editor_projection'
require 'srsrb/models'
require 'srsrb/review_scoring'
require 'srsrb/card_editing'
require 'srsrb/model_editing'
require 'srsrb/leveldb_event_store'
require 'srsrb/object_patch'
require 'srsrb/rackapp'
require 'srsrb/anki_import_parser'
require 'srsrb/importer_app'

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
    def review_projection
      @review_projection ||= ReviewProjection.new event_store
    end

    def card_editor_projection
      @card_editor_projection ||= CardEditorProjection.new event_store
    end

    # We really want layered mixins for this.
    def reviews_app
      ReviewsApp.new review_projection, deck_reviews
    end

    def card_editor_app
      CardEditorApp.new card_editor_projection, review_projection, card_editing
    end

    def model_editor_app
      ModelEditorApp.new :model_editor_stub, model_editing
    end

    def anki_import_parser
      AnkiImportParser.new model_editing, card_editing
    end

    def importer_app
      ImporterApp.new anki_import_parser
    end

    def system_test_hack_api
      SystemTestHackApi.new(nil, review_projection, card_editing, model_editing)
    end

    def app
      Rack::Cascade.new(
        [reviews_app, card_editor_app, model_editor_app, importer_app, system_test_hack_api]
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
      review_projection.start!
      card_editor_projection.start!
      models.start!
      app
    end

    def shutdown
      event_store.close
    end
  end
end

