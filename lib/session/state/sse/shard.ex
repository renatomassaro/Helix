defmodule Helix.Session.State.SSE.Shard do

  alias Helix.Session.State.SSE.Shard.Worker, as: SSEShardWorker

  @shard_list [
    :sse_state_shard_0,
    :sse_state_shard_1,
    :sse_state_shard_2,
    :sse_state_shard_3,
    :sse_state_shard_4,
    :sse_state_shard_5,
    :sse_state_shard_6,
    :sse_state_shard_7,
    :sse_state_shard_8,
    :sse_state_shard_9,
    :sse_state_shard_a,
    :sse_state_shard_b,
    :sse_state_shard_c,
    :sse_state_shard_d,
    :sse_state_shard_e,
    :sse_state_shard_f
  ]

  def get_shard_list,
    do: @shard_list

  def get_shard_id(session_id) do
    session_id
    |> String.first()
    |> map_id()
  end

  def dispatch(session_id, method, args),
    do: call_worker(get_shard_id(session_id), method, args)

  def dispatch_all(method, args, opts \\ []) do
    result_raw =
      Enum.reduce(@shard_list, %{}, fn shard_id, acc ->
        Map.put(acc, shard_id, call_worker(shard_id, method, args))
      end)

    if opts[:merge?] do
      merge_map(result_raw)
    else
      result_raw
    end
  end

  defp call_worker(shard_id, method, args),
    do: apply(SSEShardWorker, method, [shard_id | args])

  defp map_id("0"),
    do: :sse_state_shard_0
  defp map_id("1"),
    do: :sse_state_shard_1
  defp map_id("2"),
    do: :sse_state_shard_2
  defp map_id("3"),
    do: :sse_state_shard_3
  defp map_id("4"),
    do: :sse_state_shard_4
  defp map_id("5"),
    do: :sse_state_shard_5
  defp map_id("6"),
    do: :sse_state_shard_6
  defp map_id("7"),
    do: :sse_state_shard_7
  defp map_id("8"),
    do: :sse_state_shard_8
  defp map_id("9"),
    do: :sse_state_shard_9
  defp map_id("a"),
    do: :sse_state_shard_a
  defp map_id("b"),
    do: :sse_state_shard_b
  defp map_id("c"),
    do: :sse_state_shard_c
  defp map_id("d"),
    do: :sse_state_shard_d
  defp map_id("e"),
    do: :sse_state_shard_e
  defp map_id("f"),
    do: :sse_state_shard_f

  defp merge_map(result) do
    Enum.reduce(result, %{}, fn shard_id, acc ->
      Map.merge(acc, result[shard_id])
    end)
  end
end
