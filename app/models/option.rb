class Option < ApplicationRecord
  belongs_to :question
  belongs_to :dish, optional: true
  belongs_to :next_question, class_name: "Question", optional: true
  validates :text, presence: true
end
