class Dish < ApplicationRecord
  has_many :options
  has_many :histories
  validates :name, presence: true
  validates :cuisine, inclusion: { in: %w[和食 洋食 中華] }, allow_nil: true
  validates :heaviness, inclusion: { in: %w[あっさり こってり] }, allow_nil: true
end
