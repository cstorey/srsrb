require 'capybara'
require 'srsrb/rackapp'
require 'rack/test'
require 'json'

describe :SkeletonBehavior do
  let (:app) { SRSRB::RackApp.assemble }
  let (:sess) { Capybara::Session.new(:rack_test, app) }
  let (:rtsess) { Rack::Test::Session.new(Rack::MockSession.new(app)) }

  before :all do
    Capybara.save_and_open_page_path = Dir.getwd + "/tmp"
  end
  context "Reviewing pre-baked data" do
    def visit_reviews
      sess.visit '/reviews/'
    end
    
    def when_i_press_show
      sess.click_button('show answer')
    end

    def question_should_be text
      expect(sess.find('div.page')[:id]).to be == 'question-page'
      sess.within('#question') do
        expect(sess.text).to include(text)
      end
    end

    def answer_should_be text
      expect(sess.find('div.page')[:id]).to be == 'answer-page'
     sess.within('#answer') do
        expect(sess.text).to include(text)
      end
    end
    def when_score_the_card_as_good
      sess.click_button('good')
    end

    def i_should_see_all_done
      expect(sess.find('div.page')[:id]).to be == 'no-more-reviews-page'
    end

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
      visit_reviews
      question_should_be "question 1"
      when_i_press_show
      answer_should_be "answer 1"
      when_score_the_card_as_good
      question_should_be "question 2"
      when_i_press_show
      answer_should_be "answer 2"
      when_score_the_card_as_good
      i_should_see_all_done
    end

    it "should rewcord that each card has been reviewed" do
      visit_reviews
      question_should_be "question 1"
      when_i_press_show
      answer_should_be "answer 1"
      when_score_the_card_as_good
 
      card_should_have_been_reviewed id: 0, times: 1
    end
  end
end
