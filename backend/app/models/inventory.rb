class Inventory < ApplicationRecord
  belongs_to :product
  has_many :inventory_movements, dependent: :restrict_with_exception

  BUCKETS = %w[sellable quarantine refurbishment scrapped].freeze

  validates :bucket, inclusion: { in: BUCKETS }
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :bucket, uniqueness: { scope: :product_id }

  def self.quantity_for(product_id, bucket)
    find_by(product_id: product_id, bucket: bucket)&.quantity || 0
  end
end
