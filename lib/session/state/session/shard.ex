defmodule Helix.Session.State.Session.Shard do

  alias Helix.Session.State.Session.Shard.Worker, as: SessionShardWorker

  @shard_list [
    :session_state_shard_0,
    :session_state_shard_1,
    :session_state_shard_2,
    :session_state_shard_3,
    :session_state_shard_4,
    :session_state_shard_5,
    :session_state_shard_6,
    :session_state_shard_7,
    :session_state_shard_8,
    :session_state_shard_9,
    :session_state_shard_a,
    :session_state_shard_b,
    :session_state_shard_c,
    :session_state_shard_d,
    :session_state_shard_e,
    :session_state_shard_f
  ]

  def get_shard_list,
    do: @shard_list

  def get_shard_id(session_id) do
    session_id
    |> String.first()
    |> map_id()
  end

  def dispatch(session_id, method, args),
    do: apply(SessionShardWorker, method, [get_shard_id(session_id) | args])

  defp map_id("0"),
    do: :session_state_shard_0
  defp map_id("1"),
    do: :session_state_shard_1
  defp map_id("2"),
    do: :session_state_shard_2
  defp map_id("3"),
    do: :session_state_shard_3
  defp map_id("4"),
    do: :session_state_shard_4
  defp map_id("5"),
    do: :session_state_shard_5
  defp map_id("6"),
    do: :session_state_shard_6
  defp map_id("7"),
    do: :session_state_shard_7
  defp map_id("8"),
    do: :session_state_shard_8
  defp map_id("9"),
    do: :session_state_shard_9
  defp map_id("a"),
    do: :session_state_shard_a
  defp map_id("b"),
    do: :session_state_shard_b
  defp map_id("c"),
    do: :session_state_shard_c
  defp map_id("d"),
    do: :session_state_shard_d
  defp map_id("e"),
    do: :session_state_shard_e
  defp map_id("f"),
    do: :session_state_shard_f
end
