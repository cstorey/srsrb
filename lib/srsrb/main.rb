require 'srsrb/deck_view'
require 'srsrb/decks'
require 'srsrb/event_store'
require 'srsrb/object_patch'
require 'srsrb/rackapp'

module SRSRB
  module Main
    def self.assemble
      event_store = EventStore.new
      deck_changes = Decks.new event_store
      deck = DeckViewModel.new event_store
      deck.start!

      app = ReviewsApp.new deck, deck_changes
      app = CardEditorApp.new deck, deck_changes, app
      app = ModelEditorApp.new deck, deck_changes, app
      SystemTestHackApi.new(app, deck, deck_changes)
    end
  end
end

