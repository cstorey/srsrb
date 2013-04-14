require 'srsrb/model_editor_app'
require 'review_browser'

module SRSRB
  describe ModelEditorApp do
    let (:deck_view) { mock(:deck_view_model) }
    let (:decks) { mock(:decks) }
    let (:plain_app) { ModelEditorApp.new deck_view, decks }
    let (:app) { plain_app.into { |app| Rack::Session::Pool.new app } } # Rack::CommonLogger.new plain_app, $stderr }
    let (:browser) { ReviewBrowser.new app }

    let (:card) { OpenStruct.new(
      id: LexicalUUID.new, question: 'a question 1', answer: 'the answer',
      as_json: {'canary' => true})
    }

    before do
      described_class.set :raise_errors, true
      described_class.set :dump_errors, false
      described_class.set :show_exceptions, false
    end

    describe "GET /model/new" do
      let (:model) { browser.get_add_model_page }
      it "should return a form to add a new model" do
        expect(model).to be_kind_of ModelEditorPage
      end

      it "should have a blank model name by default" do
        expect(model.name).to be_empty
      end

      it "should be able to add a new field" do
        field_name = 'a field'
        expect do
          model.add_field field_name
        end.to change { model.field_names }.by([field_name])
      end

      it "should be able to add more than one new field" do
        fields = %w{one two three}
        expect do
          fields.each do |f|
            model.add_field f
          end
        end.to change { model.field_names }.by(fields)
      end

      it "should preserve the model name across reloads" do
        name = 'fred'
        model.name = name
        expect do
          model.add_field 'x'
        end.to_not change { model.name }.from(name)
      end

      context "when submitting the form" do
        let (:name) { 'vocabulary' }
        let (:fields) { %w{word meaning pronounciation} }
        let (:q_template) {  "{{ word }}" }
        let (:a_template) { "{{ meaning }} -- {{ pronounciation }}"  }

        let (:model) { browser.get_add_model_page }
        before do
          model.name = name

          fields.each do |f|
            model.add_field f
          end
          model.question_template = q_template
          model.answer_template = a_template

          decks.as_null_object
        end

        it "should name the model" do
          decks.should_receive(:name_model!).with(an_instance_of(LexicalUUID), name)
          model.create!
        end

        it "should set the templates for the model" do
          decks.should_receive(:edit_model_templates!).with(an_instance_of(LexicalUUID), q_template, a_template)
          model.create!
        end

        it "should submit a new model message when filled in and submitted" do
          fields.each do |field|
            decks.should_receive(:add_model_field!).with(an_instance_of(LexicalUUID), field)
          end
          model.create!
        end

        it "should make all deck changes with the same id" do
          uuids = Set.new
          decks.stub(:name_model!) { |id, *| uuids << id }
          decks.stub(:edit_model_templates!) { |id, *| uuids << id }
          fields.each do |field|
            decks.stub(:add_model_field!) { |id, *| uuids << id }
          end

          model.create!

          # Above, we've already demonstrated that all the appropriate decks
          # methods get called. So, iff the set has one item, they were all
          # called with the same argument.
          expect(uuids).to have(1).items

        end

        it "should show a helpful* message when it has been saved" do
          page = model.create!
          expect(page.successes).to include "Your model has now been saved"
        end

      end
    end
  end

end
