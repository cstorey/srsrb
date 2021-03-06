# coding: utf-8
require 'capybara'
require 'srsrb/main'
require 'rack/test'
require 'json'
require 'review_browser'

describe :SkeletonBehavior do
  let (:plain_app) { SRSRB::Main.assemble }
  let (:app) { plain_app } # { Rack::CommonLogger.new plain_app, $stderr }
  let (:rtsess) { Rack::Test::Session.new(Rack::MockSession.new(app)) }
  let (:browser) { SRSRB::ReviewBrowser.new app }

  before :all do
    Capybara.save_and_open_page_path = Dir.getwd + "/tmp"
  end

  before do
    SRSRB::ReviewsApp.set :raise_errors, true
    SRSRB::ReviewsApp.set :dump_errors, false
    SRSRB::ReviewsApp.set :show_exceptions, false
  end

  def card_should_have_been_reviewed opts
    id=opts.fetch(:id)
    count=opts.fetch(:times)

    rtsess.get "/raw-cards/#{id.to_guid}"
    expect(rtsess.last_response).to be_ok
    data = JSON.parse(rtsess.last_response.body)
    expect(data.fetch('review_count')).to be == count
  end

  def with_default_cards range
    model_id = LexicalUUID.new
    model = { id: model_id.to_guid, fields: %w{question answer},
      question_template: '{{ question }}', answer_template: '{{ answer }}'
    }
    cards = range.map { |x| { id: LexicalUUID.new.to_guid, data: { question: "question #{x}", answer: "answer #{x}" } } }
    rtsess.put '/editor/raw', JSON.unparse(model: model, cards:  cards)
    expect(rtsess.last_response).to be_ok
    cards.map { |x| LexicalUUID.new x.fetch(:id) }
  end

  def perform_reviews_for_day reviews, day, questions={}, answers={}
    question = browser.get_reviews_top
    while not question.all_done?
      card_id = question.card_id
      expect(question.question_text).to be == questions[card_id] if questions.has_key? card_id

      answer = question.show_answer
      expect(answer.answer_text).to be == answers[card_id] if answers.has_key? card_id

      scores = reviews.fetch(card_id) { fail "Saw a review for #{card_id.to_guid} on day #{day}, but no review expected" }
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

  context "for reviewing" do
    it "should allow reviews a series of pre-baked cards" do
      id0, id1 = with_default_cards 1..2
      should_see_reviews(
        [{day: 0,
          should_see: {id0 => [:good], id1 => [:good]}},
        ],
        questions: { id0 => "question 1", id1 => "question 2"},
        answers: {id0 => "answer 1", id1 => "answer 2"})

      expect(browser.parse).to be_all_done
    end

    it "should record that each card has been reviewed" do
      id0, id1 = with_default_cards 1..2
      perform_reviews_for_day({id0 => [:good], id1 => [:good]}, 0)

      card_should_have_been_reviewed id: id0, times: 1
    end

    it "should schedule cards as they are learnt" do
      # This assumes a "powers of two scheduler".
      id0, id1 = with_default_cards 1..2
      should_see_reviews [
        {day: 0, should_see: {id0 => [:good], id1 => [:good]}}, # both scheduled for 0+1 = 1
        {day: 1, should_see: {id0 => [:good], id1 => [:good]}}, # 0+1 scheduled for 1+2 = 3
        {day: 2, should_see: {}},
        # 0 scheduled for 3+4 = 7
        # 1 scheduled for 3+1 = 4
        {day: 3, should_see: {id0 => [:good], id1 => [:fail, :good]}},
        # 1 gets scheduled for 4+1 -> 5
        # Interval does not change as scheduled as poor
        {day: 4, should_see: {id1 => [:poor]}},
        # 1 gets scheduled for 5+2 -> 7
        {day: 5, should_see: {id1 => [:good]}},
        {day: 6, should_see: {}},
        {day: 7, should_see: {id0 => [:good], id1 => [:good]}},
      ]
    end

    it "shoud defer failures to the end of the queue"
  end

  context "for card editing" do
    it "should allow adding new cards" do
      with_default_cards 0...0
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

    it "should be possible to edit existing cards" do
      card_id, = with_default_cards 0...1
      cards = browser.list_cards
      card = cards.nth 1
      expect(card[:question]).to be == "question 0"
      expect(card[:answer]).to be == "answer 0"

      card[:question] = 'こんにちは'
      card[:answer] = 'じゃ、またね'
      card.save!

      should_see_reviews(
        [{day: 0, should_see: {card_id => [:good]}}],
        questions: {card_id =>'こんにちは'},
        answers: {card_id => 'じゃ、またね'})
    end
    it "should be possible to trash existing cards"
  end

  context "for card models" do
    it "should be possible to create a model and use it on a card" do
      model = browser.get_add_model_page
      model.name= 'vocabulary'
      model.add_field 'word'
      model.add_field 'meaning'
      model.add_field 'pronounciation'
      model.question_template= "{{ word }}"
      model.answer_template= "{{ meaning }} -- {{ pronounciation }}"
      model.create!

      card = browser.get_add_card_page
      card.set_model 'vocabulary'
      card[:word] = "fish"
      card[:meaning] = "damp animal"
      card[:pronounciation] = "ffu-issh-uh"
      confirmation = card.add_card!

      page = browser.get_reviews_top
      question = page.question_text
      answer = page.show_answer.answer_text
      expect({question: question, answer: answer}).to be ==
        {question: "fish", answer: "damp animal -- ffu-issh-uh"}
    end
    it "should be possible to add fields a model"
    it "should be possible to remove fields from a model"
    it "should be possible to change the model for a card"
  end

  context "for images" do
    it "should be possible to add an image to a card"
  end

  context "for importing and exporting" do
    let (:hangul_anki) {  Pathname.new(__FILE__).dirname.join('../data/Hangul.anki') }
    it "should be possible to import an Anki deck preserving history" do
      importer = browser.get_import_page
      importer.upload hangul_anki
      card_list = browser.list_cards
      expect(card_list).to have(41).cards
      card = card_list.card_with_question '아'
      expect(card).to have(3).card_fields
      expect(card['Hangul']).to be == '아'
      expect(card['Romanzied']).to be == 'a'
      # We have this here for completeness; we do not actually however support sound.
      expect(card['Sound']).to be == '[sound:ko_vx_1.mp3]'
    end
  end
end
