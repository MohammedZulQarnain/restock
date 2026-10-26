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
      resources :returns, only: %i[index show create] do
        member do
          post :receive
          post :start_inspection
          post :inspections, action: :create_inspection
          post "inspections/:inspection_id/complete", action: :complete_inspection, as: :complete_inspection
          post :disposition
          get :timeline
        end
      end
      get "inventory", to: "inventories#index"
      get "inventory/summary", to: "inventories#summary"
      get "inventory/movements", to: "inventories#movements"
      get "dashboard", to: "dashboard#show"
    end
  end
end
