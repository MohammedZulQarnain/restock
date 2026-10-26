class Inspection < ApplicationRecord
  belongs_to :return

  CONDITIONS = %w[new like_new good fair damaged defective].freeze
  FUNCTIONAL_STATUSES = %w[working partially_working not_working not_tested].freeze

  validates :condition, inclusion: { in: CONDITIONS }
  validates :functional_status, inclusion: { in: FUNCTIONAL_STATUSES }
  validate :return_must_be_received_or_in_inspection

  def complete!
    raise ActiveRecord::RecordInvalid.new(self) unless valid?
    raise ActiveRecord::RecordInvalid.new(self) if inspected_at.present?

    ActiveRecord::Base.transaction do
      update!(inspected_at: Time.current)
      self.return.update!(status: "inspected")
      AuditEvent.create!(
        return: self.return,
        event_type: "inspection_completed",
        details: { inspection_id: id, condition: condition, functional_status: functional_status }
      )
    end
    self
  end

  private

  def return_must_be_received_or_in_inspection
    return unless self.return
    return if %w[received inspection_in_progress].include?(self.return.status)

    errors.add(:return, "must be received before inspection")
  end
end
