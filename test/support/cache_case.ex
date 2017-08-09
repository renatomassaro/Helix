defmodule Helix.Test.CacheCase do

  import ExUnit.Assertions

  def assert_id(a = %_{id: _}, b = %_{id: _}) do
    assert a == b
  end
  def assert_id(a, b) when is_map(a) and is_map(b) do
    Enum.each(a, fn({k, v}) ->
      assert_id v, Map.get(b, k)
    end)
  end
  def assert_id(a, b) when is_list(a) and is_list(b) do
    Enum.zip(a, b)
    |> Enum.each(fn {a, b} ->
      assert_id(a, b)
    end)
  end
  def assert_id(a, b) do
    assert to_string(a) == to_string(b)
  end

  def assert_miss(query) do
    assert {:miss, _} = query
  end
  def assert_miss(query, reason) do
    assert {:miss, reason} == query
  end

  def assert_hit(query) do
    assert {:hit, _} = query
  end
end