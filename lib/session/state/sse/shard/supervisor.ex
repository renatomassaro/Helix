defmodule Helix.Session.State.SSE.Shard.Supervisor do

  use Supervisor

  alias Helix.Session.State.SSE.Shard, as: SSEShard
  alias Helix.Session.State.SSE.Shard.Worker, as: SSEShardWorker

  @doc false
  def start_link,
    do: Supervisor.start_link(__MODULE__, [])

  @doc false
  def init(_) do
    SSEShard.get_shard_list()
    |> Enum.map(&(worker(SSEShardWorker, [&1], id: &1)))
    |> supervise(strategy: :one_for_one)
  end
end
