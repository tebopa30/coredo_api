class Question < ApplicationRecord
  has_many :options, dependent: :destroy
  enum :routing, { static: 0, ai: 1 }
  validates :text, presence: true
end
