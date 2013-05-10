# coding: utf-8
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
      model_editing.stub(:edit_model_templates!)
      card_editing.stub(:add_or_edit_card!)
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

    it "should create the fields for the same model" do
      ids = Set.new
      model_editing.should_receive(:name_model!) { |id, _| ids << id }
      model_editing.should_receive(:add_model_field!) { |id, _| ids << id }
      parser.accept_upload hangul

      expect(ids).to have(1).item
    end

    it "should extract templates for the given model" do
      model_editing.should_receive(:edit_model_templates!).
        with(an_instance_of(LexicalUUID), an_instance_of(String), an_instance_of(String))
      parser.accept_upload hangul
    end

    it "should create cards for each fact in the deck" do
      card_editing.should_receive(:add_or_edit_card!).
        with(an_instance_of(LexicalUUID), an_instance_of(LexicalUUID), anything).
        exactly(37).times
      parser.accept_upload hangul
    end

    it "should create them with the given model_id" do
      model_id = nil
      card_models = {}
      model_editing.stub(:name_model!) { |id, _| model_id = id }
      card_editing.stub(:add_or_edit_card!) { |id, model_id, _| card_models[id] = model_id }

      parser.accept_upload hangul
      expect(Set.new(card_models.values)).to be == Set.new([model_id])
    end

    it "should import the data from the deck" do
      cards = {}
      card_editing.stub(:add_or_edit_card!) { |id, _, fields| cards[id] = fields }

      parser.accept_upload hangul

      expect(cards.values).to be_any { |fields|
        fields["Hangul"] == '애' &&
          fields["Romanzied"] == 'ae' &&
          fields["Sound"] == '[sound:ko_vx_26.mp3]'
      }
    end
  end
end
