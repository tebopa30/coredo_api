class Question < ApplicationRecord
  has_many :options, dependent: :destroy
  enum routing: { static: "static", ai: "ai" }
  validates :text, presence: true
end
