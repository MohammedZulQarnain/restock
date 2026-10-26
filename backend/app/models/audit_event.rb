class AuditEvent < ApplicationRecord
  belongs_to :return, optional: true

  validates :event_type, presence: true
  validates :details, presence: true
end
