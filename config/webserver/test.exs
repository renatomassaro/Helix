use Mix.Config

config :helix, Helix.Webserver.Endpoint,
  server: false,
  allowed_cors: "*",
  url: [host: "localhost", port: 4001],
  https: [
    port: 4001,
    otp_app: :helix,
    cipher_suite: :strong,
    keyfile: "priv/dev/ssl.key",
    certfile: "priv/dev/ssl.crt"
  ],
  debug_errors: false
