Rails.application.routes.draw do
  get "/health", to: proc {
    [
      200,
      { "Content-Type" => "application/json" },
      [{ status: "ok", app: "ReStock" }.to_json]
    ]
  }
  get "/api/v1/products", to: "api/v1/products#index"
end