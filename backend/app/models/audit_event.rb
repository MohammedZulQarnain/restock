class AuditEvent < ApplicationRecord
  belongs_to :return, optional: true

  validates :event_type, presence: true
  validate :details_must_be_a_hash

  private

  def details_must_be_a_hash
    errors.add(:details, "must be an object") unless details.is_a?(Hash)
  end
end
