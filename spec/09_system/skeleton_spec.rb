require 'capybara'
require 'srsrb/rackapp'
require 'rack/test'
require 'json'
require 'review_browser'

describe :SkeletonBehavior do
  let (:app) { SRSRB::RackApp.assemble }
  let (:rtsess) { Rack::Test::Session.new(Rack::MockSession.new(app)) }
  let (:browser) { SRSRB::ReviewBrowser.new app }

  before :all do
    Capybara.save_and_open_page_path = Dir.getwd + "/tmp"
  end
  context "Reviewing pre-baked data" do
    def card_should_have_been_reviewed opts
      id=opts.fetch(:id)
      count=opts.fetch(:times)

      rtsess.get "/raw-cards/#{id}"
      expect(rtsess.last_response).to be_ok
      data = JSON.parse(rtsess.last_response.body)
      expect(data.fetch('review_count')).to be == count
    end

    before do
      SRSRB::RackApp.set :raise_errors, true
      SRSRB::RackApp.set :dump_errors, false
      SRSRB::RackApp.set :show_exceptions, false
    end

    it "reviews a series of pre-baked cards" do
      page = browser.get_reviews_top
      expect(page.question_text).to be == "question 1"
      page = page.show_answer
      expect(page.answer_text).to be == "answer 1"
      page = page.score_card :good

      expect(page.question_text).to be == "question 2"
      page = page.show_answer
      expect(page.answer_text).to be == "answer 2"
      page = page.score_card :good

      expect(page).to be_all_done
    end

    it "should rewcord that each card has been reviewed" do
      page = browser.get_reviews_top
      expect(page.question_text).to be == "question 1"
      page = page.show_answer
      expect(page.answer_text).to be == "answer 1"
      page = page.score_card :good
 
      card_should_have_been_reviewed id: 0, times: 1
    end

    it "should schedule cards as they are learnt" do
      # This assumes a "powers of two scheduler".
      # So, assuming good reviews
      pending do
        with_cards 0..1
        should_see_reviews [
          {day: 0, should_see: [0,1]}, # both scheduled for 0+1 = 1
          {day: 1, should_see: [0,1]}, # 0+1 scheduled for 1+2 = 3
          {day: 2, should_see: []},
          # 0 scheduled for 3+4 = 7
          # 1 scheduled for 3+1 = 4
          {day: 3, should_see: {0 => [:good], 1 => [:fail, :okay]}},
          # 1 gets scheduled for 4+1 -> 5
          # Interval does not change as scheduled as poor
          {day: 4, should_see: {1 => [:poor]}},
          # 1 gets scheduled for 5+2 -> 7
          {day: 5, should_see: {1 => [:good]}},
          {day: 6, should_see: {}},
          {day: 7, should_see: {0 => [:good], 1 => [:good]}},
        ]
      end
    end
  end
end
