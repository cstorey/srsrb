require 'srsrb/anki_import_parser'

module SRSRB
  describe AnkiImportParser do
    let (:model_editing) { mock :model_editing }
    let (:card_editing) { mock :card_editing }

    let (:parser) { AnkiImportParser.new model_editing, card_editing }

    let (:hangul_anki) {  Pathname.new(__FILE__).dirname.join('../../data/Hangul.anki') }
    let (:hangul) {  hangul_anki.open }

    before do
      model_editing.stub(:name_model!)
      model_editing.stub(:add_model_field!)
    end

    it "should first parse and create a model" do
      model_editing.should_receive(:name_model!).with(an_instance_of(LexicalUUID), 'Basic')
      parser.accept_upload hangul
    end

    it "should create the fields for the model" do
      model_editing.should_receive(:add_model_field!).with(an_instance_of(LexicalUUID), 'Hangul')
      # This is a typo in the original data file. Oops.
      model_editing.should_receive(:add_model_field!).with(an_instance_of(LexicalUUID), 'Romanzied')
      model_editing.should_receive(:add_model_field!).with(an_instance_of(LexicalUUID), 'Sound')
      parser.accept_upload hangul
    end
  end
end
