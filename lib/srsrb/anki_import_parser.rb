require 'sqlite3'
require 'sequel'

# TODO: Add another model and some basic cards to the example data. Eg: a
# vocab model, with forward and reverse cards.
module SRSRB
  class AnkiImportParser
    def initialize model_editing, card_editing
      self.model_editing = model_editing
      self.card_editing = card_editing
    end

    def accept_upload file
      db = Sequel.sqlite file.path
      import_models db
    end

    private
    def import_models db
      model_id = LexicalUUID.new
      db[:models].all.each do |r|
        model_editing.name_model! model_id, r.fetch(:name)
        db[:fieldModels].each do |fm|
          model_editing.add_model_field! model_id, fm.fetch(:name)
        end
      end

      db[:cardModels].select_map([:qformat, :aformat]).each do |(question, answer)|
          model_editing.edit_model_templates! model_id, question, answer
      end

      db[:facts].
        join(:fields, :factId => :id).
        join(:fieldModels, :id => :fieldModelId).
        select_map([:facts__id, :fieldModels__name, :fields__value]).
        group_by(&:first).
        each do |fact_id, grouped|
          data = grouped.inject(Hamster.hash) { |h, (_, field, value)| h.put(field, value) }
          card_editing.add_or_edit_card! LexicalUUID.new, model_id, data
      end
    end

    attr_accessor :model_editing, :card_editing
  end
end
