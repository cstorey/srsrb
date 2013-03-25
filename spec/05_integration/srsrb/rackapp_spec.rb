require 'srsrb/rackapp'
require 'capybara'

module SRSRB
  describe RackApp do
    let (:deck_view) { mock(:deck_view_model) }
    let (:app) { RackApp.new deck_view }
    let (:browser) { ReviewBrowser.new app }

    let (:card) { OpenStruct.new(id: 42, question: 'a question 1', answer: 'the answer') }

    describe "GET /reviews" do
      before do
        described_class.set :raise_errors, true
        described_class.set :dump_errors, false
        described_class.set :show_exceptions, false

        deck_view.stub(:next_card)
      end

      it "should query the next card in the deck" do
        deck_view.should_receive(:next_card).with()
        page = browser.get_reviews_top
      end

      it "should show the question from the next card" do
        deck_view.stub(:next_card).with().and_return(card)
        page = browser.get_reviews_top
        expect(page.question_text).to be == card.question
      end

      it "should show the done page when the deck is exhausted" do
        deck_view.stub(:next_card).with().and_return(nil)
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
    end

    class ReviewBrowser
      include RSpec::Matchers
      def initialize app
        self.app = app
        self.browser = Capybara::Session.new(:rack_test, app)
      end

      def get_reviews_top
        browser.visit '/reviews/'
        parse
      end

      def show_answer id
        browser.visit "/reviews/#{id}"
        parse
      end

      def parse 
        id = browser.find("div.page[1]")[:id]
        fail "No id (#{id.inspect}) found in page:\n" + browser.html unless id
        case id 
        when 'question-page' 
          QuestionPage.new(browser)
        when 'answer-page' 
          AnswerPage.new(browser)
        when 'no-more-reviews-page' 
          DeckFinishedPage.new(browser)
        else
          fail "No page id recognised: #{id}"
        end
      end

      attr_accessor :app, :browser
    end

    class Page
      def initialize browser
        self.browser = browser
      end

      attr_accessor :browser
    end
 
    class QuestionPage < Page
      def question_text
        browser.find('div#question').text
      end
      def show_answer
        browser.click_button 'show answer'
      end
    end

    class AnswerPage < Page
      def answer_text
        puts browser.html
        browser.find('div#answer').text
      end
    end

    class DeckFinishedPage < Page
    end
  end
end
