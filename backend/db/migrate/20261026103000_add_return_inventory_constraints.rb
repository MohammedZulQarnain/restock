class AddReturnInventoryConstraints < ActiveRecord::Migration[7.1]
  def change
    add_check_constraint :returns, "quantity > 0", name: "returns_quantity_positive"
    add_check_constraint :inventories, "quantity >= 0", name: "inventories_quantity_nonnegative"
    add_check_constraint :inventory_movements, "quantity_delta <> 0", name: "inventory_movements_delta_nonzero"
    add_check_constraint :returns,
      "status IN ('registered', 'received', 'inspection_in_progress', 'inspected', 'completed', 'cancelled')",
      name: "returns_status_valid"
    add_check_constraint :inspections,
      "condition IN ('new', 'like_new', 'good', 'fair', 'damaged', 'defective')",
      name: "inspections_condition_valid"
    add_check_constraint :inventories,
      "bucket IN ('sellable', 'quarantine', 'refurbishment', 'scrapped')",
      name: "inventories_bucket_valid"
  end
end
