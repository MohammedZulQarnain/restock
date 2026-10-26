class InventoryMovement < ApplicationRecord
  belongs_to :product
  belongs_to :inventory
  belongs_to :return, optional: true

  validates :movement_type, presence: true
  validates :quantity_delta, numericality: { only_integer: true, other_than: 0 }
  validates :reason, presence: true
  validates :idempotency_key, presence: true, uniqueness: true
end
