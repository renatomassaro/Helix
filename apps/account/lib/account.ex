defmodule Helix.Account.App do

  use Application

  alias HELF.Router
  alias Helix.Account.Controller.AccountService
  alias Helix.Account.Repo

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Ensure secret_key is set or the application shouldn't start
    unless Application.get_env(:guardian, Guardian)[:secret_key] do
      raise RuntimeError, message: "Guardian secret_key not set"
    end

    Router.register("account.create", "account:create", [:email, :password, :password_confirmation])
    Router.register("account.login", "account:login", [:email, :password])

    children = [
      worker(AccountService, []),
      worker(Repo, [])
    ]

    opts = [strategy: :one_for_one, name: Account.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
