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
      model_editing.should_receive(:name_model!).with(an_instance_of(LexicalUUID), 'Hangul')
      model_editing.should_receive(:name_model!).with(an_instance_of(LexicalUUID), 'Vocab')
      parser.accept_upload hangul
    end

    it "should only name the models in the deck" do
      model_editing.should_receive(:name_model!).exactly(2).times
      parser.accept_upload hangul
    end

    it "should create the fields for the model" do
      models = Hash.new { |h, model_id| h[model_id] = [] }
      model_editing.stub(:add_model_field!) do |model_id, field|
        models[model_id] << field
      end
      parser.accept_upload hangul
      # This is a typo in the original data file. Oops.
      expect(Set.new(models.values)).to be == Set.new(
        [%w{Term Translation Romanized}, %w{Hangul Romanzied Sound}])
    end

    it "should assign the correct name to the correct model" do
      names = Hash.new
      models = Hash.new { |h, model_id| h[model_id] = [] }

      model_editing.stub(:name_model!) do |model_id, name|
        names[model_id] = name
      end
      model_editing.stub(:add_model_field!) do |model_id, field|
        models[names.fetch(model_id)] << field
      end

      parser.accept_upload hangul

      expect(models.fetch("Vocab")).to include("Term")
      expect(models.fetch("Hangul")).to include("Hangul")
    end

    it "should extract the first templates for the given model" do
      model_editing.should_receive(:edit_model_templates!).exactly(2).times.
        with(an_instance_of(LexicalUUID), an_instance_of(String), an_instance_of(String))
      parser.accept_upload hangul
    end

    it "should rather create a card view for each card layout in the deck"

    it "should create cards for each fact in the deck" do
      card_editing.should_receive(:add_or_edit_card!).
        with(an_instance_of(LexicalUUID), an_instance_of(LexicalUUID), anything).
        exactly(41).times
      parser.accept_upload hangul
    end

    it "should create them with the given model_id" do
      models = {}
      card_models = {}
      model_editing.stub(:name_model!) { |id, name| models[id] = name }
      card_editing.stub(:add_or_edit_card!) { |id, model_id, _| card_models[id] = model_id }

      parser.accept_upload hangul

      counts_by_model = card_models.map { |card, model| [models.fetch(model), card] }.
        group_by(&:first).
        map { |k, v| [k, v.size] }.
        into { |kvs| Hash[kvs] }

      expect(counts_by_model).to be == {'Hangul' => 37, 'Vocab' => 4}
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
