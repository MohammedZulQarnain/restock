class CorsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    origin = env["HTTP_ORIGIN"]
    allowed_origin = ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173")

    if env["REQUEST_METHOD"] == "OPTIONS"
      return [204, cors_headers(origin, allowed_origin).merge(
        "Access-Control-Allow-Methods" => "GET, POST, PATCH, PUT, DELETE, OPTIONS",
        "Access-Control-Allow-Headers" => "Content-Type, Authorization",
        "Access-Control-Max-Age" => "600"
      ), []]
    end

    status, headers, body = @app.call(env)
    [status, headers.merge(cors_headers(origin, allowed_origin)), body]
  end

  private

  def cors_headers(origin, allowed_origin)
    return {} unless origin == allowed_origin

    {
      "Access-Control-Allow-Origin" => allowed_origin,
      "Vary" => "Origin"
    }
  end
end
