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
      browser.visit "/reviews/#{id.to_guid}"
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
      when 'card-editor-page'
        CardEditorPage.new(browser, self)
      when 'model-editor-page'
        ModelEditorPage.new(browser, self)
      else
        fail "No page id recognised: #{id}"
      end
    end

    def review_upto day
      browser.visit "/review-upto?day=#{day}"
    end

    def get_add_card_page
      browser.visit '/editor/new'
      parse
    end

    def get_add_model_page
      browser.visit '/model/new'
      parse
    end

    attr_accessor :app, :browser
  end

  class Page
    def initialize browser, parent
      self.browser = browser
      self.parent = parent
    end

    def all_done?
      false
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

    def card_id
      id = browser.find(:xpath, '//*[@data-card-id]')['data-card-id']
      LexicalUUID.new id
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

  class CardEditorPage < Page
    def [](field)
      browser.find("#field-#{field}").text.strip
    end
    def []=(field, value)
      browser.fill_in "field-#{field}", with: value
    end

    def add_card!
      browser.click_button 'add card'
      parent.parse
    end

    def last_added_card_id
      id = browser.find('#last-added-card-id').text
      LexicalUUID.new id
    end

    def set_model name
      browser.select(name, from: 'card model')
    end
  end

  class ModelEditorPage < Page

    def name
      browser.find(:fillable_field, 'model name').value || ''
    end

    def name= name
      browser.fill_in('model name', with: name)
    end

    def field_names
      browser.all('input.field-name').map { |r| r.value }
    end

    def add_field name
      browser.fill_in('new field name', with: name)
      browser.click_button 'add field'
    end

    def question_template= tmpl
      browser.fill_in('question template', with: tmpl)
    end

    def answer_template= tmpl
      browser.fill_in('answer template', with: tmpl)
    end

    def create!
      browser.click_button 'save'
    end
  end
end
