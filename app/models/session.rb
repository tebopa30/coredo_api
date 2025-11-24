class Session < ApplicationRecord
  has_many :answers, dependent: :destroy
  belongs_to :dish, optional: true
  before_create -> { self.uuid ||= SecureRandom.uuid }
end
