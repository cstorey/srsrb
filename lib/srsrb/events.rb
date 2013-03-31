require 'hamsterdam'

module SRSRB
  CardReviewed = Hamsterdam::Struct.define(:score, :next_due_date)
end
