use Mix.Config

prefix = System.get_env("HELIX_DB_PREFIX") || "helix"

config :helix, Helix.Core.Repo,
  database: prefix <> "_dev_core"

config :helix, :node,
  public_ip: "127.0.0.1",
  private_ip: "127.0.0.1",
  provider: "dev",
  region: "local"
