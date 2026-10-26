class Return < ApplicationRecord
  belongs_to :product
  has_many :inspections, dependent: :restrict_with_exception
  has_one :disposition, dependent: :restrict_with_exception
  has_many :inventory_movements, dependent: :restrict_with_exception
  has_many :audit_events, dependent: :restrict_with_exception

  STATUSES = %w[registered received inspection_in_progress inspected completed cancelled].freeze
  REASONS = %w[damaged defective incorrect_item unwanted other].freeze

  before_validation :assign_return_number, on: :create

  validates :return_number, presence: true, uniqueness: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :reason, inclusion: { in: REASONS }
  validates :status, inclusion: { in: STATUSES }
  validate :product_must_be_active, on: :create

  scope :recent_first, -> { order(created_at: :desc) }

  private

  def assign_return_number
    self.return_number ||= "RET-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
  end

  def product_must_be_active
    errors.add(:product, "must be active for a new return") if product && !product.active?
  end
end
