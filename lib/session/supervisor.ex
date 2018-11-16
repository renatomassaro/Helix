defmodule Helix.Session.Supervisor do

  use Supervisor

  alias Helix.Session.State.Supervisor, as: SessionStateSupervisor
  alias Helix.Session.Repo

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      supervisor(Repo, []),
      supervisor(SessionStateSupervisor, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
