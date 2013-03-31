require 'capybara'
require 'srsrb/rackapp'
require 'rack/test'
require 'json'
require 'review_browser'

describe :SkeletonBehavior do
  let (:plain_app) { SRSRB::RackApp.assemble }
  let (:app) { plain_app } # { Rack::CommonLogger.new plain_app, $stderr }
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


    def with_default_cards range
      payload = range.map { |x| { id: LexicalUUID.new.to_guid, data: { question: "question #{x}", answer: "answer #{x}" } } }
      rtsess.put '/editor/raw', JSON.unparse(payload)
      expect(rtsess.last_response).to be_ok
      pp put: payload
    end

    it "reviews a series of pre-baked cards" do
      with_default_cards 1..2
      should_see_reviews(
        [{day: 0,
          should_see: {0 => [:good], 1 => [:good]}},
        ],
        questions: { 0 => "question 1", 1 => "question 2"},
        answers: {0 => "answer 1", 1 => "answer 2"})

      expect(browser.parse).to be_all_done
    end

    it "should rewcord that each card has been reviewed" do
      perform_reviews_for_day({0 => [:good], 1 => [:good]}, 0)

      card_should_have_been_reviewed id: 0, times: 1
    end

    def perform_reviews_for_day reviews, day, questions={}, answers={}
      question = browser.get_reviews_top
      while not question.all_done?
        card_id = question.card_id
        expect(question.question_text).to be == questions[card_id] if questions.has_key? card_id

        answer = question.show_answer
        expect(answer.answer_text).to be == answers[card_id] if answers.has_key? card_id

        scores = reviews.fetch(card_id) { fail "Saw a review for #{card_id} on day #{day}, but no review expected" }
        question = answer.score_card scores.shift
        reviews.delete card_id if reviews[card_id].empty?
      end

      fail "Expected to do more reviews: #{reviews.inspect} , but none found on day #{day}" if not reviews.empty?
    end

    def should_see_reviews reviews, content={}
      reviews.each do |spec|
        day = spec.fetch :day
        browser.review_upto day

        expected_reviews = spec.fetch :should_see
        perform_reviews_for_day expected_reviews, day,
          content.fetch(:questions, {}),
          content.fetch(:answers, {})
      end

    end

    it "should schedule cards as they are learnt" do
      # This assumes a "powers of two scheduler".
      with_default_cards 1..2
      should_see_reviews [
        {day: 0, should_see: {0 => [:good], 1 => [:good]}}, # both scheduled for 0+1 = 1
        {day: 1, should_see: {0 => [:good], 1 => [:good]}}, # 0+1 scheduled for 1+2 = 3
        {day: 2, should_see: {}},
        # 0 scheduled for 3+4 = 7
        # 1 scheduled for 3+1 = 4
        {day: 3, should_see: {0 => [:good], 1 => [:fail, :good]}},
        # 1 gets scheduled for 4+1 -> 5
        # Interval does not change as scheduled as poor
        {day: 4, should_see: {1 => [:poor]}},
        # 1 gets scheduled for 5+2 -> 7
        {day: 5, should_see: {1 => [:good]}},
        {day: 6, should_see: {}},
        {day: 7, should_see: {0 => [:good], 1 => [:good]}},
      ]
    end

    it "should allow adding new cards" do
      pending "incomplete" do
        card = browser.get_add_card_page
        card[:question] = "Hello"
        card[:answer] = "Goodbye"
        confirmation = card.add_card!

        card_id = confirmation.last_added_card_id

        should_see_reviews(
          [{day: 0, should_see: {card_id => [:good]}}],
          questions: {card_id => "Hello"},
          answers: {card_id => "Goodbye"})
      end
    end
  end
end
