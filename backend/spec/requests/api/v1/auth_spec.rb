require "rails_helper"

RSpec.describe "Authentication API", type: :request do
  let!(:user) { User.create!(email: "login@example.test", password: "demo-password", role: "warehouse_operator") }

  it "issues a token for valid credentials" do
    post "/api/v1/auth/login", params: { email: user.email, password: "demo-password" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "token")).to be_present
    expect(user.reload.token_digest).to be_present
  end

  it "rejects invalid credentials" do
    post "/api/v1/auth/login", params: { email: user.email, password: "wrong-password" }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects protected requests without a bearer token" do
    get "/api/v1/products"

    expect(response).to have_http_status(:unauthorized)
  end

  it "does not allow a read-only user to create products" do
    read_only = User.create!(email: "reader@example.test", password: "demo-password", role: "read_only")
    token = read_only.issue_api_token!

    post "/api/v1/products",
         params: { product: { name: "Desk Lamp", sku: "HOME-READ-001", category: "Home" } },
         as: :json,
         headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:forbidden)
  end

  it "revokes a token on logout" do
    token = user.issue_api_token!
    headers = { "Authorization" => "Bearer #{token}" }

    post "/api/v1/auth/logout", headers: headers
    get "/api/v1/auth/me", headers: headers

    expect(response).to have_http_status(:unauthorized)
  end
end
