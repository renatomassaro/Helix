use Mix.Config

config :helix, Helix.Entity.Repo,
  priv: "priv/repo/entity",
  size: 4,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("HELIX_DB_USER") || "postgres",
  password: System.get_env("HELIX_DB_PASS") || "postgres",
  hostname: System.get_env("HELIX_DB_HOST") || "localhost",
  types: HELL.PostgrexTypes,
  after_connect: {
    Helix.Entity.Repo, :set_schema, ["helix"]
  }
