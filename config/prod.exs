use Mix.Config

config :logger,
  compile_time_purge_level: :info,
  metadata: [:request_id],
  backends: [
    {LoggerFileBackend, :warn},
    {LoggerFileBackend, :error}
  ],
  utc_log: true,
  level: :info

config :logger, :warn,
  path: "/var/log/helix/warn.log",
  level: :warn

config :logger, :error,
  path: "/var/log/helix/error.log",
  level: :error
