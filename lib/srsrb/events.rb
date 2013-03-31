require 'hamsterdam'

module SRSRB
  CardReviewed = Hamsterdam::Struct.define(:score, :next_due_date)
  CardEdited = Hamsterdam::Struct.define(:card_fields)
end
