defmodule Helix.Webserver.Endpoint do
  use Phoenix.Endpoint, otp_app: :helix

  # socket "/", Helix.Websocket

  plug Corsica,
    origins: Application.get_env(:helix, Helix.Webserver.Endpoint)[:allowed_cors],
    allow_headers: ["content-type", "x-request-id"]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :helix,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  plug Plug.RequestId
  plug Plug.Logger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session,
    store: :cookie,
    key: "_helix_key",
    signing_salt: "4ErDD9Ul"

  plug Helix.Webserver.Router
end
