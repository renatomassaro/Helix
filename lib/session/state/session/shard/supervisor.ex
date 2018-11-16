defmodule Helix.Session.State.Session.Shard.Supervisor do

  use Supervisor

  alias Helix.Session.State.Session.Shard, as: SessionShard
  alias Helix.Session.State.Session.Shard.Worker, as: SessionShardWorker

  @doc false
  def start_link,
    do: Supervisor.start_link(__MODULE__, [])

  @doc false
  def init(_) do
    SessionShard.get_shard_list()
    |> Enum.map(&(worker(SessionShardWorker, [&1], id: &1)))
    |> supervise(strategy: :one_for_one)
  end
end
