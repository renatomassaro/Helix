defmodule Helix.Webserver.Endpoint do
  use Phoenix.Endpoint, otp_app: :helix

  plug Corsica,
    origins: Application.get_env(:helix, Helix.Webserver.Endpoint)[:allowed_cors],
    allow_headers: ["content-type"],
    expose_headers: ["x-request-id"],
    allow_credentials: true,
    max_age: 3600

  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug Helix.Webserver.Router
end
