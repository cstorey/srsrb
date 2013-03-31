module SRSRB
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
      browser.find('div#answer').text
    end

    def score_card label
      browser.click_button label
    end
  end

  class DeckFinishedPage < Page
  end
end
