use Mix.Config

config :helix,
  ecto_repos: [
    Helix.Account.Repo,
    Helix.Cache.Repo,
    Helix.Client.Repo,
    Helix.Core.Repo,
    Helix.Entity.Repo,
    Helix.Log.Repo,
    Helix.Network.Repo,
    Helix.Notification.Repo,
    Helix.Universe.Repo,
    Helix.Process.Repo,
    Helix.Server.Repo,
    Helix.Software.Repo,
    Helix.Story.Repo
  ],
  env: Mix.env

config :distillery, no_warn_missing: [:burette, :elixir_make]

import_config "#{Mix.env}.exs"
import_config "hevent.exs"
import_config "*/config.exs"
import_config "*/#{Mix.env}.exs"
