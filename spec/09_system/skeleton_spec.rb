require 'capybara'
require 'srsrb/rackapp'
require 'rack/test'
require 'json'
require 'review_browser'

describe :SkeletonBehavior do
  let (:app) { Rack::CommonLogger.new SRSRB::RackApp.assemble, $stderr }
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

    def review_up_until_day day
      rtsess.put "/review-until-day", day.to_s
      expect(rtsess.last_response).to be_ok
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

    def with_cards range
      # Nothing for now--we assume that cards with ids in the given range
      # already exist.
    end

    def perform_reviews_for_day reviews
      question = browser.get_reviews_top
      while not question.all_done?
        card_id = question.card_id
        answer = question.show_answer
        scores = reviews.fetch card_id
        question = answer.score_card scores.shift
        reviews.delete card_id if reviews[card_id].empty?
      end

      expect(reviews).to be == {}
    end

    def should_see_reviews reviews
      reviews.each do |spec|
        day = spec.fetch :day
        expected_reviews = spec.fetch :should_see
        review_up_until_day day

        perform_reviews_for_day expected_reviews
      end

    end

    it "should schedule cards as they are learnt" do
      # This assumes a "powers of two scheduler".
      # So, assuming good reviews
      pending do
        with_cards 1..2
        should_see_reviews [
          {day: 0, should_see: {0 => [:good], 1 => [:good]}}, # both scheduled for 0+1 = 1
          {day: 1, should_see: {0 => [:good]}}, # 0+1 scheduled for 1+2 = 3
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
