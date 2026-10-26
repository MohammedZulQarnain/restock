require "rails_helper"

RSpec.describe "Products API", type: :request do
  describe "GET /api/v1/products" do
    it "returns a paginated product collection" do
      Product.create!(name: "Headphones", sku: "AUD-001", category: "Audio")
      get "/api/v1/products"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.fetch("data").length).to eq(1)
      expect(body.dig("data", 0, "sku")).to eq("AUD-001")
      expect(body.dig("meta", "total")).to eq(1)
    end

    it "filters by category" do
      Product.create!(name: "Headphones", sku: "AUD-001", category: "Audio")
      Product.create!(name: "Jacket", sku: "APP-001", category: "Clothing")
      get "/api/v1/products", params: { category: "Audio" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("data").map { |item| item.fetch("category") }).to eq(["Audio"])
    end
  end

  describe "POST /api/v1/products" do
    it "creates a product" do
      post "/api/v1/products", params: {
        product: { name: "Desk Lamp", sku: "HOME-001", category: "Home" }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(Product.find_by!(sku: "HOME-001").name).to eq("Desk Lamp")
    end

    it "returns field errors for invalid data" do
      post "/api/v1/products", params: { product: { name: "", sku: "", category: "" } }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "details").keys).to include("name", "sku", "category")
    end
  end
end
