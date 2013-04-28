# coding: utf-8
require 'srsrb/rackapp'
require 'srsrb/object_patch'
require 'capybara'
require 'json'
require 'review_browser'
require 'rack/test'

module SRSRB
  describe SystemTestHackApi do
    let (:deck_view) { mock(:deck_view_model) }
    let (:card_editing) { mock(:card_editing) }
    let (:model_editing) { mock(:model_editing) }
    let (:card_reviews) { mock(:card_reviews) }

    let (:parent_app) { ReviewsApp.new deck_view, card_reviews }
    let (:plain_app) { SystemTestHackApi.new(parent_app, deck_view, card_editing, model_editing) }
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
        card_editing.as_null_object
        model_editing.as_null_object
      end

      it "should create model fields" do
        model_fields.each do |f|
          model_editing.should_receive(:add_model_field!).with(model_id, f)
        end

        rtsess.put "/editor/raw", JSON.unparse(model: model_json, cards: [])
        expect(rtsess.last_response).to be_ok
      end

      it "should create model fields" do
        model_editing.should_receive(:edit_model_templates!).with(model_id, q_tmpl, a_tmpl)

        rtsess.put "/editor/raw", JSON.unparse(model: model_json, cards: [])
        expect(rtsess.last_response).to be_ok
      end


      it "should create one card for each card item" do
        card_data.each do |d|
          card_editing.should_receive(:add_or_edit_card!).with(d.fetch(:id), model_id, d.fetch(:data))
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
