use Mix.Config

config :comeonin, :bcrypt_log_rounds, 2

config :account, Helix.Account.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

config :guardian, Guardian,
  secret_key: System.get_env("HELIX_JWK_KEY") || "testkey"
