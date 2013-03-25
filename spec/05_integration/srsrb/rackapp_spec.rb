require 'srsrb/rackapp'
require 'capybara'

module SRSRB
  describe RackApp do
    before :all do
    end
    describe "GET /reviews" do
      let (:deck_view) { mock(:deck_view_model).as_null_object }
      let (:app) { RackApp.new deck_view }
      let (:browser) { ReviewBrowser.new app }

      let (:question) { OpenStruct.new(id: 42, text: 'a question 1') }

      before do
        described_class.set :raise_errors, true
        described_class.set :dump_errors, false
        described_class.set :show_exceptions, false
      end

      it "should render okay" do
        page = browser.get_reviews_top
        expect(page).to be_kind_of(QuestionPage)
      end

      it "should query the next card in the deck" do
        deck_view.should_receive(:next_card).with()
        page = browser.get_reviews_top
      end

      it "should show tghe question from the next card" do
        deck_view.stub(:next_card).with().and_return(question)
        page = browser.get_reviews_top
        expect(page.question_text).to be == "a question 1"
      end

    end

    class ReviewBrowser
      include RSpec::Matchers
      def initialize app
        self.app = app
        self.browser = Capybara::Session.new(:rack_test, app)
      end

      def get_reviews_top
        browser.visit '/reviews'
        parse
      end

      def parse 
        id = browser.find("div.page[1]")[:id]
        fail "No id (#{id.inspect}) found in page:\n" + browser.html unless id
        case id 
        when 'question-page' 
          QuestionPage.new(browser)
        else
          fail "No page id recognised: #{id}"
        end
      end

      attr_accessor :app, :browser
    end

    class QuestionPage
      def initialize browser
        self.browser = browser
      end

      def question_text
        browser.find('div#question').text
      end

      attr_accessor :browser
    end
  end
end
