class Message < ApplicationRecord
  belongs_to :conversation

  enum :sender_type, {
    customer: 0,
    bot: 1,
    seller: 2
  }

  validates :content, presence: true
end
