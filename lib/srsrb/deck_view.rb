module SRSRB
  class DeckViewModel
    def next_card
      QuestionViewModel.new
    end
  end

  class QuestionViewModel
    def text
      inspect
    end
  end
end
