require 'hamsterdam'
require 'hamster/hash'
require 'hamster/vector'
require 'atomic'

module SRSRB
  class ReviewProjection
    def initialize event_store
      self.event_store = event_store
      self.cards = Atomic.new Hamster.hash
      self._card_models = Atomic.new Hamster.hash
      self._card_model_id_by_card = Atomic.new Hamster.hash
    end

    def start!
      event_store.subscribe self
    end

    def next_card_upto time
      return if cards.get.empty?
      next_card = cards.get.values.sort_by { |c| c.due_date }.first
      next_card if next_card.due_date <= time
    end

    def card_for id
      cards.get[id]
    end

    def enqueue_card card
      update_card(card.id) { card }
    end

    def all_cards
      cards.get.values
    end

    def handle_event id, event, _version
      case event
        when CardReviewed then handle_card_reviewed id, event
        when CardEdited then handle_card_edited id, event
        when ModelTemplatesChanged then handle_model_templates_changed id, event
      end
    end

    private
    def handle_card_reviewed id, event
      update_card(id) { |card0|
        card0.set_review_count(card0.review_count.to_i.succ).
          set_due_date(event.next_due_date)
      }
    end

    def handle_card_edited id, event
      model = model_for event.model_id

      question = model.format_question_with(event.card_fields)
      answer = model.format_answer_with(event.card_fields)

      update_card(id) { |card| card.set_question(question).set_answer(answer) }
    end

    def handle_card_model_changed id, event
      _card_model_id_by_card.update { |idx| idx.put(id, event.model_id) }
    end

    def update_model id, &block
      _card_models.update do |old_cards|
        old_model = old_cards[id]
        new_model = block.call old_model
        old_cards.put id, new_model
      end
    end

    def handle_model_templates_changed id, event
      update_model(id) {
        CardFormat.new(id: id).
          set_question_template(event.question).
          set_answer_template(event.answer)
      }
    end

    def update_card id, &block
      cards.update { |oldver|
        oldver.fetch(id) { Card.new id: id }.
          into { |old_card| block.call old_card }.
          into { |new_card| oldver.put(id, new_card) }
      }
    end

    def model_for id
      _card_models.get.find { |m| true }.last
    end

    attr_accessor :cards, :event_store, :_card_models, :_card_model_id_by_card

    class CardFormat < Hamsterdam::Struct.define(:id, :question_template, :answer_template)
      def fields
        super || Hamster.vector
      end

      def format_question_with card_fields
        format question_template, card_fields
      end
      def format_answer_with card_fields
        format answer_template, card_fields
      end

      private
      def format str, fields
        str.gsub(/{{\s*(\w+)\s*}}/) { |m| fields.fetch($1, "Unknown field: #{$1}") }
      end
    end

  end

  class Card < Hamsterdam::Struct.define(:id, :question, :answer, :review_count, :due_date)
    def as_json
      Hash.new.tap do |h|
        self.class.field_names.each do |f|
          h[f] = public_send f
        end
      end
    end

    def due_date
      super || 0
    end
  end

end
