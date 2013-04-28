require 'sqlite3'
require 'sequel'

module SRSRB
  class AnkiImportParser
    def initialize model_editing, card_editing
      self.model_editing = model_editing
    end

    def accept_upload file
      db = Sequel.sqlite file.path
      import_models db
    end

    private
    def import_models db
      db[:models].all.each do |r|
        model_editing.name_model! LexicalUUID.new, r.fetch(:name)
      end
    end

    attr_accessor :model_editing
  end
end
