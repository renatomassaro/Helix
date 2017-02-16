use Mix.Config

config :comeonin, :bcrypt_log_rounds, 2

config :guardian, Guardian,
  secret_key: System.get_env("HELIX_JWK_KEY") || "devkey"

