use Mix.Config

prefix = System.get_env("HELIX_DB_PREFIX") || "helix"

config :helix, Helix.Session.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: prefix <> "_test_session",
  ownership_timeout: 90_000
