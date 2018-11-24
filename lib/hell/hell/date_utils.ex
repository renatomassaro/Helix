defmodule HELL.DateUtils do

  def utc_now(:microsecond),
    do: DateTime.utc_now()
  def utc_now(:second),
    do: DateTime.truncate(DateTime.utc_now(), :second)

  @doc """
  Generates a date in the future, according to the given precision. Defaults to
  seconds.
  """
  def date_after(seconds, precision \\ :second) do
    DateTime.utc_now()
    |> DateTime.to_unix(precision)
    |> Kernel.+(seconds)
    |> DateTime.from_unix!(precision)
  end

  @doc """
  Generates a date in the past, according to the given precision. Defaults to
  seconds.
  """
  def date_before(seconds, precision \\ :second),
    do: date_after(-seconds, precision)
end
