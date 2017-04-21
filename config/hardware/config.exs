use Mix.Config

config :helix, Helix.Hardware.Repo,
  priv: "priv/repo/hardware",
  size: 4,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("HELIX_DB_USER") || "postgres",
  password: System.get_env("HELIX_DB_PASS") || "postgres",
  hostname: System.get_env("HELIX_DB_HOST") || "localhost",
  types: HELL.PostgrexTypes,
  after_connect: {
    Helix.Hardware.Repo, :set_schema, ["helix"]
  }
