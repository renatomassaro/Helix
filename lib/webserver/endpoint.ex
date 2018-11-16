defmodule Helix.Webserver.Endpoint do
  use Phoenix.Endpoint, otp_app: :helix

  plug Corsica,
    origins: Application.get_env(:helix, Helix.Webserver.Endpoint)[:allowed_cors],
    allow_headers: ["content-type", "x-request-id"],
    allow_credentials: true

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug Helix.Webserver.Router
end
