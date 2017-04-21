use Mix.Config

config :helix, Helix.NPC.Repo,
  priv: "priv/repo/npc",
  size: 4,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("HELIX_DB_USER") || "postgres",
  password: System.get_env("HELIX_DB_PASS") || "postgres",
  hostname: System.get_env("HELIX_DB_HOST") || "localhost",
  types: HELL.PostgrexTypes,
  after_connect: {
    Helix.NPC.Repo, :set_schema, ["helix"]
  }
