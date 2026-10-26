require "rails_helper"

RSpec.describe "Returns API", type: :request do
  let!(:product) { Product.create!(name: "Wireless Headphones", sku: "AUD-RET-001", category: "Audio") }

  def create_return
    post "/api/v1/returns", params: {
      return: { product_id: product.id, quantity: 2, reason: "damaged", order_reference: "ORDER-DEMO-1" }
    }, as: :json
  end

  it "registers a return without increasing sellable inventory" do
    expect { create_return }.to change(Return, :count).by(1)
    expect(response).to have_http_status(:created)
    expect(Inventory.quantity_for(product.id, "sellable")).to eq(0)
  end

  it "receives a registered return without increasing sellable inventory" do
    create_return
    return_id = response.parsed_body.dig("data", "id")
    post "/api/v1/returns/#{return_id}/receive"

    expect(response).to have_http_status(:ok)
    expect(Return.find(return_id).status).to eq("received")
    expect(Inventory.quantity_for(product.id, "sellable")).to eq(0)
  end

  it "rejects receiving a return twice" do
    create_return
    return_id = response.parsed_body.dig("data", "id")
    post "/api/v1/returns/#{return_id}/receive"
    post "/api/v1/returns/#{return_id}/receive"

    expect(response).to have_http_status(:conflict)
  end
end
