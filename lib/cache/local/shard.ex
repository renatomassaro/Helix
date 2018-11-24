defmodule Helix.Cache.Local.Shard do

  alias HELL.Utils
  alias Helix.Cache.Local.Shard.Worker, as: CacheShardWorker

  @shard_list [
    :cache_shard_0,
    :cache_shard_1,
    :cache_shard_2,
    :cache_shard_3,
    :cache_shard_4,
    :cache_shard_5,
    :cache_shard_6,
    :cache_shard_7,
    :cache_shard_8,
    :cache_shard_9,
    :cache_shard_a,
    :cache_shard_b,
    :cache_shard_c,
    :cache_shard_d,
    :cache_shard_e,
    :cache_shard_f
  ]

  def get_shard_list,
    do: @shard_list

  def get_shard_id(cache_id) do
    cache_id
    |> to_string()
    |> String.first()
    |> map_id()
  end

  def dispatch(cache_id, prefix, type, args) do
    method = Utils.concat_atom(prefix, type)

    apply(CacheShardWorker, method, [get_shard_id(cache_id) | args])
  end

  defp map_id("0"),
    do: :cache_shard_0
  defp map_id("1"),
    do: :cache_shard_1
  defp map_id("2"),
    do: :cache_shard_2
  defp map_id("3"),
    do: :cache_shard_3
  defp map_id("4"),
    do: :cache_shard_4
  defp map_id("5"),
    do: :cache_shard_5
  defp map_id("6"),
    do: :cache_shard_6
  defp map_id("7"),
    do: :cache_shard_7
  defp map_id("8"),
    do: :cache_shard_8
  defp map_id("9"),
    do: :cache_shard_9
  defp map_id("a"),
    do: :cache_shard_a
  defp map_id("b"),
    do: :cache_shard_b
  defp map_id("c"),
    do: :cache_shard_c
  defp map_id("d"),
    do: :cache_shard_d
  defp map_id("e"),
    do: :cache_shard_e
  defp map_id("f"),
    do: :cache_shard_f
end
