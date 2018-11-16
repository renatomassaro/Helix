defmodule Helix.Session.State.Supervisor do

  use Supervisor

  alias Helix.Session.State.Session, as: SessionState

  @doc false
  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  @doc false
  def init(_) do
    children = [
      worker(SessionState, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
