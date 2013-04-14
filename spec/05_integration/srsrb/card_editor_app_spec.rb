require 'srsrb/card_editor_app'
require 'review_browser'

module SRSRB
  describe CardEditorApp do
    let (:deck_view) { mock(:deck_view_model) }
    let (:decks) { mock(:decks) }
    let (:plain_app) { CardEditorApp.new deck_view, decks }
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

    describe "GET /editor/new" do
      let (:card_fields) { 
          Hash['qanda' => %w{question answer},
               'vocabulary' => %w{word meaning pronounciation}]
      }

      let (:card_models) {
        card_models = model_names.map { |name|
          OpenStruct.new id: LexicalUUID.new, name:name, fields: Hamster.vector(*card_fields.fetch(name))
        }.inject(Hamster.vector) {
          |s, x| s.add x
        }
      }
      let (:default_model_id) { card_models.first.id }

      before do
        deck_view.stub(:card_models).and_return(card_models.map(&:id))
        card_models.each do |model|
          deck_view.stub(:card_model).with(model.id).and_return(model)
        end
      end

      context "with multiple models" do
        let (:model_names) { %w{qanda vocabulary} }

        it "should display a list of card models by name" do
          page = browser.get_add_card_page
          card_models_as_dictionary = card_models.
            to_enum.
            flat_map { |m| [m.id.to_guid, m.name] }.
            into { |kvs| Hash[*kvs] }
          expect(page.card_models).to be == card_models_as_dictionary
        end

        it "should use a given default model" do
          page = browser.get_add_card_page
          expect(page.card_fields).to be == card_fields.fetch('qanda')
        end

        it "should show fields for the new model when the model is changed" do
          page = browser.get_add_card_page
          expect do
            page = page.set_model 'vocabulary'
          end.to change { page.card_fields }.
            from(card_fields.fetch('qanda')).
            to(card_fields.fetch('vocabulary'))
        end
      end

      context "with a single model with multiple fields" do
        let (:model_names) { %w{vocabulary} }
        it "should render the card fields described by the model" do
          model_name = model_names.first
          page = browser.get_add_card_page
          expect(page.card_fields).to be == card_fields.fetch(model_name)
        end

        it "should submit the card edit with the fields described in the model" do
          model_name = model_names.first
          page = browser.get_add_card_page
          page[:word] = "a word"
          page[:meaning] = "the meaning"
          page[:pronounciation] = "how it sounds"
          decks.should_receive(:add_or_edit_card!).
            with an_instance_of(LexicalUUID), {
            "word" => "a word",
            "meaning" => "the meaning",
            "pronounciation" => "how it sounds",
          }
          decks.should_receive(:set_model_for_card!).with(an_instance_of(LexicalUUID), default_model_id)

          page.add_card!
        end

        it "should validate that all fields are present"
      end

      context "with a question and answer fields" do
      let (:model_names) { %w{qanda} }
      let (:question) { "a question" }
      let (:answer) {  "an answer" }

      it "should return an empty form" do
        page = browser.get_add_card_page
        expect(page).to be_kind_of CardEditorPage
        expect(page[:question]).to be_empty
        expect(page[:answer]).to be_empty
      end

      it "should submit a card edit message and set the card_model when the form is filled in and submitted" do
        page = browser.get_add_card_page
        page[:question] = "a question"
        page[:answer] = "an answer"

        decks.should_receive(:set_model_for_card!).with(an_instance_of(LexicalUUID), default_model_id)
        decks.should_receive(:add_or_edit_card!).with(an_instance_of(LexicalUUID), { 'question' => question, 'answer' => answer })

        page.add_card!
      end

      it "should include the id of the previously added card for the system tests" do 
        decks.as_null_object
        page = browser.get_add_card_page
        page[:question] = "a question"
        page[:answer] = "an answer"
        page = page.add_card!

        expect(page.last_added_card_id).to be_kind_of LexicalUUID
      end

      it "should show a helpful* message when it has been saved" do
        decks.as_null_object
        page = browser.get_add_card_page
        page[:question] = "a question"
        page[:answer] = "an answer"
        page = page.add_card!

        expect(page.successes).to include "Your card has now been saved"
      end

      it "should indicate a problem when the question other is missing"
      end

      context "with no card models" do
        let (:model_names) { [] }

        it "should return an appropriate message" do
          page = browser.get_add_card_page
          expect(page).to be_kind_of CardModelMissingErrorPage
        end
      end
    end

    describe 'GET /editor/' do
      let (:a_card) { OpenStruct.new(
        id: LexicalUUID.new, question: 'a question 1', answer: 'the answer')
      }
      it "should list all cards in the deck" do
        deck_view.stub(:all_cards).and_return([a_card].to_enum)
        page = browser.list_cards
        expect(page).to have(1).cards
        the_card = page.cards.first
        expect(the_card)
      end
    end

    describe 'GET /editor/:card_id' do
      let (:card_fields) { { 'word' => 'foo', 'meaning' => 'metasyntax', 'reading' => 'fffuuu' } }
      let (:card_data) { OpenStruct.new( id: LexicalUUID.new, fields: card_fields) }

      before do
        deck_view.stub(:editable_card_for).with(card_data.id).and_return(card_data)
        decks.stub(:add_or_edit_card!)
      end

      it "should yield a card edit form" do
        page = browser.get_card_edit_page card_data.id.to_guid
        expect(page).to be_kind_of CardEditorPage
      end

      it "should show the  current fields" do
        page = browser.get_card_edit_page card_data.id.to_guid
        expect(page.card_field_dict).to be == card_fields
      end


      it "should save the updated data" do
        page = browser.get_card_edit_page card_data.id.to_guid

        decks.should_receive(:add_or_edit_card!).with card_data.id, card_fields

        page.save!
      end

      it "should show a helpful* message when it has been saved" do
        page = browser.get_card_edit_page card_data.id.to_guid
        page =  page.save!

        expect(page.successes).to include "Your card has now been saved"
      end
    end
  end
end
