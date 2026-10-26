require "rails_helper"

RSpec.describe "Returns API", type: :request do
  let(:token) { User.create!(email: "warehouse-operator@example.test", password: "demo-password", role: "warehouse_operator").issue_api_token! }
  let(:auth_headers) { { "Authorization" => "Bearer #{token}" } }
  let(:inspector_token) { User.create!(email: "inspector@example.test", password: "demo-password", role: "inspector").issue_api_token! }
  let(:inspector_headers) { { "Authorization" => "Bearer #{inspector_token}" } }
  let!(:product) { Product.create!(name: "Wireless Headphones", sku: "AUD-RET-001", category: "Audio") }

  def create_return
    post "/api/v1/returns", params: {
      return: { product_id: product.id, quantity: 2, reason: "damaged", order_reference: "ORDER-DEMO-1" }
    }, as: :json, headers: auth_headers
  end

  it "registers a return without increasing sellable inventory" do
    expect { create_return }.to change(Return, :count).by(1)
    expect(response).to have_http_status(:created)
    expect(Inventory.quantity_for(product.id, "sellable")).to eq(0)
  end

  it "receives a registered return without increasing sellable inventory" do
    create_return
    return_id = response.parsed_body.dig("data", "id")
    post "/api/v1/returns/#{return_id}/receive", headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(Return.find(return_id).status).to eq("received")
    expect(Inventory.quantity_for(product.id, "sellable")).to eq(0)
  end

  it "rejects receiving a return twice" do
    create_return
    return_id = response.parsed_body.dig("data", "id")
    post "/api/v1/returns/#{return_id}/receive", headers: auth_headers
    post "/api/v1/returns/#{return_id}/receive", headers: auth_headers
    expect(response).to have_http_status(:conflict)
  end

  it "completes inspection and records an eligible disposition through the API" do
    create_return
    return_id = response.parsed_body.dig("data", "id")
    post "/api/v1/returns/#{return_id}/receive", headers: auth_headers

    post "/api/v1/returns/#{return_id}/inspections",
         params: { inspection: { condition: "good", functional_status: "working", accessories_complete: true, issue_found: false } },
         as: :json, headers: inspector_headers
    expect(response).to have_http_status(:created)
    inspection_id = response.parsed_body.dig("data", "id")

    post "/api/v1/returns/#{return_id}/inspections/#{inspection_id}/complete", headers: inspector_headers
    expect(response).to have_http_status(:ok)
    expect(Return.find(return_id).status).to eq("inspected")

    post "/api/v1/returns/#{return_id}/disposition",
         params: { disposition: { disposition_type: "restock", reason: "Inspection passed" } },
         as: :json, headers: inspector_headers
    expect(response).to have_http_status(:created)
    expect(Inventory.quantity_for(product.id, "sellable")).to eq(2)
    expect(Return.find(return_id).status).to eq("completed")
  end
end
