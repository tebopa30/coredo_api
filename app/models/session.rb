class Session < ApplicationRecord
  has_many :answers, dependent: :destroy
  belongs_to :dish, optional: true

  before_create -> { self.uuid ||= SecureRandom.uuid }
  before_create -> { self.messages ||= [] }
  before_create -> { self.state ||= {} }

  # state を安全に初期化
  def ensure_state!
    self.state ||= {}
  end

  # messages を安全に初期化
  def ensure_messages!
    self.messages ||= []
  end
end