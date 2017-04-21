use Mix.Config

prefix = System.get_env("HELIX_DB_PREFIX") || "helix"

config :comeonin, :bcrypt_log_rounds, 2

config :helix, Helix.Account.Repo,
  database: prefix <> "_dev_account",
  after_connect: {
    Helix.Account.Repo, :set_schema, ["helix"]
  }
