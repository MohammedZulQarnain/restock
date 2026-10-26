Rails.application.routes.draw do
  get "/health", to: proc {
    [
      200,
      { "Content-Type" => "application/json" },
      [{ status: "ok", app: "ReStock" }.to_json]
    ]
  }

  namespace :api do
    namespace :v1 do
      resources :products, only: %i[index show create update destroy]
    end
  end
end
