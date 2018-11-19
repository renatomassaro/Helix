use Mix.Config

# Configures the endpoint
default_key = "asdfghjklzxcvbnm,./';[]-=1234567890!"
config :helix, Helix.Webserver.Endpoint,
  secret_key_base: System.get_env("HELIX_ENDPOINT_SECRET_KEY") || default_key,
  render_errors: [view: Helix.Webserver.ErrorView, accepts: ~w(json)],
  pubsub: [name: Helix.Webserver.PubSub, adapter: Phoenix.PubSub.PG2]
  # https: [compress: true]

config :helix, :migration_token, "defaultMigrationToken"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :mime, :types, %{
  "text/event-stream" => ["txt"]
}
