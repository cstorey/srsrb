require 'srsrb/rackapp'
require 'capybara'
require 'json'
require 'review_browser'

module SRSRB
  describe RackApp do
    let (:deck_view) { mock(:deck_view_model) }
    let (:decks) { mock(:decks) }
    let (:plain_app) { RackApp.new deck_view, decks }
    let (:app) { Rack::CommonLogger.new plain_app, $stderr }
    let (:browser) { ReviewBrowser.new app }

    let (:card) { OpenStruct.new(
      id: 42, question: 'a question 1', answer: 'the answer', 
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

      it "should include a review button that scores the card"  do
        deck_view.stub(:card_for).with(card.id).and_return(card)
        deck_view.stub(:next_card_upto)

        page = browser.show_answer card.id

        decks.should_receive(:score_card!).with(card.id, :good)
        page.score_card :good
      end
    end

    # These are hacks to get the system tests to work.
    describe "GET /raw-cards/:id" do
      let (:rtsess) { Rack::Test::Session.new(Rack::MockSession.new(app)) }
      it "should return the card as plain JSON for now" do
        deck_view.stub(:card_for).with(card.id).and_return(card)
        rtsess.get "/raw-cards/#{card.id}" 
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
  end
end
