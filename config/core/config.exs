use Mix.Config

config :helix, Helix.Core.Repo,
  priv: "priv/repo/core",
  pool_size: 3,
  username: System.get_env("HELIX_DB_USER") || "postgres",
  password: System.get_env("HELIX_DB_PASS") || "postgres",
  hostname: System.get_env("HELIX_DB_HOST") || "localhost",
  types: HELL.PostgrexTypes
