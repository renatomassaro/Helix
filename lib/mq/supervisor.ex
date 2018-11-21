defmodule Helix.MQ.Supervisor do

  use Supervisor

  alias Helix.MQ

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      worker(MQ.Server, []),
      worker(MQ.Router, []),
      worker(MQ.Client, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
