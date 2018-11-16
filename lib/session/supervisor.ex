defmodule Helix.Session.Supervisor do

  use Supervisor

  alias Helix.Session.State.Session, as: SessionState
  alias Helix.Session.Repo

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      supervisor(Repo, []),
      supervisor(SessionState, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
