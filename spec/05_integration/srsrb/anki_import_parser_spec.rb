require 'srsrb/anki_import_parser'

module SRSRB
  describe AnkiImportParser do
    let (:model_editing) { mock :model_editing }
    let (:card_editing) { mock :card_editing }

    let (:parser) { AnkiImportParser.new model_editing, card_editing }

    let (:hangul_anki) {  Pathname.new(__FILE__).dirname.join('../../data/Hangul.anki') }
    let (:hangul) {  hangul_anki.open }

    it "should first parse and create a model" do
      model_editing.should_receive(:name_model!).with(an_instance_of(LexicalUUID), 'Basic')
      parser.accept_upload hangul
    end
  end
end
