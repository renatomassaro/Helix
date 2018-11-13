use Mix.Config

config :helix, Helix.Webserver.Endpoint,
  server: true,
  allowed_cors: ~r/http?.*localhost*/,
  url: [
    host: "localhost",
    port: 4000
  ],
  https: [
    port: 4000,
    otp_app: :helix,
    cipher_suite: :strong,
    keyfile: "priv/dev/ssl.key",
    certfile: "priv/dev/ssl.crt"
  ],
  debug_errors: true,
  code_reloader: false,
  check_origin: false,
  watchers: []

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
