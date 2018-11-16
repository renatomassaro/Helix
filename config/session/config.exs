use Mix.Config

config :helix, Helix.Session.Repo,
  priv: "priv/repo/session",
  pool_size: 2,
  username: System.get_env("HELIX_DB_USER") || "postgres",
  password: System.get_env("HELIX_DB_PASS") || "postgres",
  hostname: System.get_env("HELIX_DB_HOST") || "localhost",
  types: HELL.PostgrexTypes
