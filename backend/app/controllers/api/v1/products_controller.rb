class Api::V1::ProductsController < ApplicationController
  before_action :set_product, only: %i[show update destroy]

  def index
    products = Product.all
    products = products.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params.key?(:active)
    products = products.where(category: params[:category]) if params[:category].present?

    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      products = products.where("name ILIKE :term OR sku ILIKE :term OR category ILIKE :term", term: term)
    end

    products = products.order(:name)
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [[params.fetch(:per_page, 20).to_i, 1].max, 100].min
    total = products.count

    render json: {
      data: products.offset((page - 1) * per_page).limit(per_page).as_json,
      meta: { page: page, per_page: per_page, total: total, total_pages: (total.to_f / per_page).ceil }
    }
  end

  def show
    render json: { data: @product.as_json }
  end

  def create
    product = Product.new(product_params)
    if product.save
      render json: { data: product.as_json }, status: :created
    else
      render json: { error: { code: "VALIDATION_FAILED", message: "The product could not be created.", details: product.errors.to_hash } }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render json: { error: { code: "DUPLICATE_SKU", message: "A product with this SKU already exists." } }, status: :conflict
  end

  def update
    if @product.update(product_params)
      render json: { data: @product.as_json }
    else
      render json: { error: { code: "VALIDATION_FAILED", message: "The product could not be updated.", details: @product.errors.to_hash } }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render json: { error: { code: "DUPLICATE_SKU", message: "A product with this SKU already exists." } }, status: :conflict
  end

  def destroy
    if @product.update(active: false)
      head :no_content
    else
      render json: { error: { code: "DEACTIVATION_FAILED", message: "The product could not be deactivated." } }, status: :unprocessable_entity
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: { code: "NOT_FOUND", message: "Product not found." } }, status: :not_found
  end

  def product_params
    params.require(:product).permit(:name, :sku, :category, :description, :active)
  end
end
