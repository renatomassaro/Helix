use Mix.Config

import_config "../../auth/config/config.exs"
import_config "../../helf_router/config/config.exs"

config :server, ecto_repos: [HELM.Server.Repo]
config :server, HELM.Server.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "server_service",
  username: System.get_env("HELIX_DB_USER"),
  password: System.get_env("HELIX_DB_PASS"),
  hostname: System.get_env("HELIX_DB_HOST")
