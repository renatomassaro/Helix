defmodule HELM.Auth.Mixfile do
  use Mix.Project

  def project do
    [app: :auth,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: applications(Mix.env),
     mod: {HELM.Auth.App, []}]
  end

  defp applications(:dev), do: applications(:all) ++ [:remix]
  defp applications(_all), do: [:logger, :helf_broker]

  defp deps do
    [{:helf_broker, in_umbrella: true},
     {:guardian, "~> 0.12.0"},
     {:remix, "~> 0.0.1", only: :dev}]
  end
end
