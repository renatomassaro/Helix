use Mix.Config

config :logger,
  backends: [:console, {LoggerFileBackend, :debug}],
  utc_log: true,
  level: :debug

config :logger, :debug,
  path: "./helix.log",
  level: :debug

config :hevent, :opts,
  async: true
