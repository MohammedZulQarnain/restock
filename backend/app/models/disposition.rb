class Disposition < ApplicationRecord
  belongs_to :return
  belongs_to :inspection

  TYPES = %w[restock refurbish quarantine scrap].freeze

  validates :disposition_type, inclusion: { in: TYPES }
  validates :reason, presence: true
  validate :inspection_must_be_completed
  validate :one_disposition_per_return

  private

  def inspection_must_be_completed
    errors.add(:inspection, "must be completed before disposition") if inspection && inspection.inspected_at.nil?
  end

  def one_disposition_per_return
    existing = self.return&.disposition
    errors.add(:return, "already has a disposition") if existing && existing != self
  end
end
