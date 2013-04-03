require 'hamsterdam'

module SRSRB
  CardReviewed = Hamsterdam::Struct.define(:score, :next_due_date)
  CardEdited = Hamsterdam::Struct.define(:card_fields)
  ModelNamed = Hamsterdam::Struct.define(:name)
  ModelTemplatesChanged = Hamsterdam::Struct.define(:question, :answer)
  ModelFieldAdded = Hamsterdam::Struct.define(:field)
end
