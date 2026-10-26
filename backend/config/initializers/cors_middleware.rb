require Rails.root.join("lib/cors_middleware")

Rails.application.config.middleware.insert_before 0, CorsMiddleware
