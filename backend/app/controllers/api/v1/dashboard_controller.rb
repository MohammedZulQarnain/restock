class Api::V1::DashboardController < ApplicationController
  def show
    status_counts = Return.group(:status).count
    inventory_counts = Inventory.group(:bucket).sum(:quantity)
    render json: { data: {
      returns_total: Return.count,
      returns_by_status: status_counts,
      awaiting_receipt: status_counts.fetch("registered", 0),
      awaiting_inspection: status_counts.fetch("received", 0) + status_counts.fetch("inspection_in_progress", 0),
      awaiting_disposition: status_counts.fetch("inspected", 0),
      completed_returns: status_counts.fetch("completed", 0),
      inventory: {
        sellable: inventory_counts.fetch("sellable", 0),
        quarantine: inventory_counts.fetch("quarantine", 0),
        refurbishment: inventory_counts.fetch("refurbishment", 0),
        scrapped: inventory_counts.fetch("scrapped", 0)
      },
      recent_returns: Return.includes(:product).recent_first.limit(8).as_json(include: { product: { only: %i[id name sku] } }),
      recent_movements: InventoryMovement.includes(:product).order(created_at: :desc).limit(8).as_json(include: { product: { only: %i[id name sku] } })
    } }
  end
end
