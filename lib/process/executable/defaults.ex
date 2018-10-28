defmodule Helix.Process.Executable.Defaults do

  @doc """
  By default, return empty `custom` map.
  """
  def custom(_, _, _, _),
    do: %{}

  @doc """
  By default, return empty `resources` map.
  """
  def resources(_, _, _, _, _),
    do: %{}

  @doc """
  By default, no `source_file` is set.
  """
  def source_file(_, _, _, _, _),
    do: nil

  @doc """
  By default, no `target_file` is set.
  """
  def target_file(_, _, _, _, _),
    do: nil

  @doc """
  By default, no `source_connection` is set.
  """
  def source_connection(_, _, _, _, _),
    do: nil

  @doc """
  By default, no `target_connection` is set.
  """
  def target_connection(_, _, _, _, _),
    do: nil

  @doc """
  By default, no `target_process` is set.
  """
  def target_process(_, _, _, _, _),
    do: nil

  @doc """
  By default, no `target_log` is set.
  """
  def target_log(_, _, _, _, _),
    do: nil

  @doc """
  By default, no `source_bank_account` is set.
  """
  def source_bank_account(_, _, _, _, _),
    do: {nil, nil}

  @doc """
  By default, no `target_bank_account` is set.
  """
  def target_bank_account(_, _, _, _, _),
    do: {nil, nil}
end
