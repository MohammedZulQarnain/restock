class Api::V1::InventoriesController < ApplicationController
  def index
    inventories = Inventory.includes(:product).joins(:product).order("products.name", :bucket)
    inventories = inventories.where(bucket: params[:bucket]) if params[:bucket].present?
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      inventories = inventories.where("products.name ILIKE :term OR products.sku ILIKE :term", term: term)
    end
    render json: { data: inventories.map { |item|
      { id: item.id, product: { id: item.product_id, name: item.product.name, sku: item.product.sku },
        bucket: item.bucket, quantity: item.quantity, updated_at: item.updated_at }
    } }
  end

  def movements
    movements = InventoryMovement.includes(:product, :return).order(created_at: :desc)
    movements = movements.where(product_id: params[:product_id]) if params[:product_id].present?
    movements = movements.where(return_id: params[:return_id]) if params[:return_id].present?
    render json: { data: movements.limit(200).map { |movement|
      movement.as_json(include: { product: { only: %i[id name sku] } })
    }, meta: { limit: 200 } }
  end

  def summary
    quantities = Inventory.group(:bucket).sum(:quantity)
    render json: { data: {
      sellable: quantities.fetch("sellable", 0),
      quarantine: quantities.fetch("quarantine", 0),
      refurbishment: quantities.fetch("refurbishment", 0),
      scrapped: quantities.fetch("scrapped", 0),
      total_tracked: quantities.values.sum
    } }
  end
end
