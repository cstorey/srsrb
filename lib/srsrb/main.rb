require 'srsrb/deck_view'
require 'srsrb/decks'
require 'srsrb/event_store'
require 'srsrb/object_patch'
require 'srsrb/rackapp'

module SRSRB
  module Lazy
    def lazy name, &generator
      ivar = :"@__#{name}"
      define_method name do
        if not value = instance_variable_get(ivar)
          value = instance_eval &generator
          instance_variable_set ivar, value
        end
        value
      end
    end
  end

  class Main
    def self.assemble
      self.new.assemble
    end

    extend Lazy

    lazy(:event_store) { EventStore.new }
    lazy(:deck_changes) { Decks.new event_store }
    lazy(:deck_reviews) { ReviewScoring.new event_store }
    lazy(:deck) { DeckViewModel.new event_store }

    # We really want layered mixins for this.
    lazy(:app0) { ReviewsApp.new deck, deck_reviews }
    lazy(:app1) { CardEditorApp.new deck, deck_changes, app0 }
    lazy(:app2) { ModelEditorApp.new deck, deck_changes, app1 }
    lazy(:app3) { SystemTestHackApi.new(app2, deck, deck_changes) }

    def assemble
      deck.start!
      app3
    end
  end
end

