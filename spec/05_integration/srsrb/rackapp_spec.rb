# coding: utf-8
require 'srsrb/rackapp'
require 'srsrb/object_patch'
require 'capybara'
require 'json'
require 'review_browser'
require 'rack/test'

module SRSRB
  describe RackApp do
    let (:deck_view) { mock(:deck_view_model) }
    let (:decks) { mock(:decks) }
    let (:plain_app) { RackApp.new deck_view, decks }
    let (:app) { plain_app } # Rack::CommonLogger.new plain_app, $stderr }
    let (:browser) { ReviewBrowser.new app }

    let (:card) { OpenStruct.new(
      id: LexicalUUID.new, question: 'a question 1', answer: 'the answer', 
      as_json: {'canary' => true}) 
    }

    before do
      described_class.set :raise_errors, true
      described_class.set :dump_errors, false
      described_class.set :show_exceptions, false
      deck_view.stub(:next_card_upto)
    end

    describe "GET /reviews" do
      it "should query the next card in the deck" do
        deck_view.should_receive(:next_card_upto).with(0)
        page = browser.get_reviews_top
      end

      it "should show the question from the next card" do
        deck_view.stub(:next_card_upto).with(0).and_return(card)
        page = browser.get_reviews_top
        expect(page.question_text).to be == card.question
      end

      it "should show the done page when the deck is exhausted" do
        deck_view.stub(:next_card_upto).with(0).and_return(nil)
        page = browser.get_reviews_top
        expect(page).to be_kind_of(DeckFinishedPage)
      end

    end
    describe "GET /reviews/$id" do
      before do
      end
      it "should lookup the answer when answer requested" do
        deck_view.should_receive(:card_for).with(card.id).and_return(card)
        browser.show_answer card.id
      end

      it "should show the answer text" do
        deck_view.stub(:card_for).with(card.id).and_return(card)
        page = browser.show_answer card.id
        expect(page.answer_text).to be == card.answer
      end

      it "should include a review button that scores the card as 'good'"  do
        deck_view.stub(:card_for).with(card.id).and_return(card)
        deck_view.stub(:next_card_upto)

        page = browser.show_answer card.id

        decks.should_receive(:score_card!).with(card.id, :good)
        page.score_card :good
      end

      it "should include a review button that fails the card"  do
        deck_view.stub(:card_for).with(card.id).and_return(card)
        deck_view.stub(:next_card_upto)

        page = browser.show_answer card.id

        decks.should_receive(:score_card!).with(card.id, :fail)
        page.score_card :fail
      end

      it "should include a review button that scores the card as poor"  do
        deck_view.stub(:card_for).with(card.id).and_return(card)
        deck_view.stub(:next_card_upto)

        page = browser.show_answer card.id

        decks.should_receive(:score_card!).with(card.id, :poor)
        page.score_card :poor
      end

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

      it "should indicate a problem when the question other is missing"
      end
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
      end
    end
  end

  describe SystemTestHackApi do
    let (:deck_view) { mock(:deck_view_model) }
    let (:decks) { mock(:decks) }
    let (:parent_app) { RackApp.new deck_view, decks }
    let (:plain_app) { SystemTestHackApi.new(parent_app, deck_view, decks) }
    let (:app) { plain_app } # Rack::CommonLogger.new plain_app, $stderr }
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

    let (:rtsess) { Rack::Test::Session.new(Rack::MockSession.new(app)) }
    describe "GET /raw-cards/:id" do
      it "should return the card as plain JSON for now" do
        deck_view.stub(:card_for).with(card.id).and_return(card)
        rtsess.get "/raw-cards/#{card.id.to_guid}" 
        expect(rtsess.last_response).to be_ok
        expect(rtsess.last_response.headers['content-type'].split(';').first).to be == 'application/json'
        data = JSON.parse(rtsess.last_response.body)
        expect(data).to be == card.as_json
      end
    end

    describe "PUT /review-upto-day" do
      it "should set the current day" do
        browser.review_upto 3
        deck_view.should_receive(:next_card_upto).with(3)
        page = browser.get_reviews_top
      end
    end

    describe "PUT /editor/raw" do
      let (:model_id) { LexicalUUID.new }
      let (:model_fields) { %w{foo bar baz} }
      let (:card_data) { [
        {id: LexicalUUID.new, data: { 'question' =>  "foo", 'answer' =>  "bar" } },
        {id: LexicalUUID.new, data: { 'question' =>  "baz", 'answer' =>  "qux" } },
      ] }

      let (:q_tmpl) { 'question template' }
      let (:a_tmpl) { 'answer template' }

      let (:model_json) { {
        id: model_id.to_guid, fields: model_fields,
        question_template: q_tmpl, answer_template: a_tmpl
      } }

      before do
        decks.as_null_object
      end

      it "should create model fields" do
        model_fields.each do |f|
          decks.should_receive(:add_model_field!).with(model_id, f)
        end

        rtsess.put "/editor/raw", JSON.unparse(model: model_json, cards: [])
        expect(rtsess.last_response).to be_ok
      end

      it "should create model fields" do
        decks.should_receive(:edit_model_templates!).with(model_id, q_tmpl, a_tmpl)

        rtsess.put "/editor/raw", JSON.unparse(model: model_json, cards: [])
        expect(rtsess.last_response).to be_ok
      end


      it "should create one card for each card item" do
        card_data.each do |d|
          decks.should_receive(:set_model_for_card!).with(d.fetch(:id), model_id)
          decks.should_receive(:add_or_edit_card!).with(d.fetch(:id), d.fetch(:data))
        end

        card_json = card_data.map { |r|
          r.merge(id: r.fetch(:id).to_guid)
        }
        rtsess.put "/editor/raw", JSON.unparse(model: model_json, cards: card_json)
        expect(rtsess.last_response).to be_ok
      end
    end
  end
end
