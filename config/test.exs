use Mix.Config

config :logger,
  level: :warn,
  compile_time_purge_level: :warn

config :helf,
  driver: :sync

config :logger,
  backends: [:console],
  level: :warn

config :hevent, :opts,
  async: false
