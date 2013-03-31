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
        QuestionPage.new(browser, self)
      when 'answer-page'
        AnswerPage.new(browser, self)
      when 'no-more-reviews-page'
        DeckFinishedPage.new(browser, self)
      else
        fail "No page id recognised: #{id}"
      end
    end

    attr_accessor :app, :browser
  end

  class Page
    def initialize browser, parent
      self.browser = browser
      self.parent = parent
    end

    attr_accessor :browser, :parent
  end

  class QuestionPage < Page
    def question_text
      browser.find('div#question').text
    end
    def show_answer
      browser.click_button 'show answer'
      parent.parse
    end
  end

  class AnswerPage < Page
    def answer_text
      browser.find('div#answer').text
    end

    def score_card label
      browser.click_button label
      parent.parse
    end
  end

  class DeckFinishedPage < Page
    def all_done?
      true
    end
  end
end
