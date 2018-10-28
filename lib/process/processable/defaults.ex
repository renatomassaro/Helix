defmodule Helix.Process.Processable.Defaults do

  @doc """
  Called when the process receives a SIGKILL.

  Defines what happens should the process get killed. Reason is also passed as
  argument.

  Default behaviour is to delete the process.
  """
  def on_kill(_process, _data, _reason),
    do: {:delete, []}

  @doc """
  Called when the process receives a SIG_RETARGET.

  Defines what should happen when the process is asked to look for a new target.

  Default behaviour is to ignore the signal.
  """
  def on_retarget(_process, _data, _),
    do: {:noop, []}

  @doc """
  Called when the process receives a SIG_SRC_CONN_DELETED.

  Defines what should happen when the process' underlying connection is closed.

  Default behaviour is to send a SIGKILL to itself.
  """
  def on_source_connection_closed(_process, _data, _connection),
    do: {{:SIGKILL, :src_connection_closed}, []}

  @doc """
  Called when the process receives a SIG_TGT_CONN_DELETED.

  Defines what should happen when the process' target connection is closed.

  Default behaviour is to send a SIGKILL to itself.
  """
  def on_target_connection_closed(_process, _data, _connection),
    do: {{:SIGKILL, :tgt_connection_closed}, []}

  @doc """
  Called when the process receives a SIG_TGT_LOG_REVISED.

  Defines what should happen when the process' target log is revised.

  Default behaviour is to ignore the signal.
  """
  def on_target_log_revised(_process, _data, _log),
    do: {:noop, []}

  @doc """
  Called when the process receives a SIG_TGT_LOG_RECOVERED.

  Defines what should happen when the process' target log is recovered.

  Default behaviour is to ignore the signal.
  """
  def on_target_log_recovered(_process, _data, _log),
    do: {:noop, []}

  @doc """
  Called when the process receives a SIG_TGT_LOG_DESTROYED.

  Defines what should happen when the process' target log is destroyed.

  Default behaviour is to ignore the signal.
  """
  def on_target_log_destroyed(_process, _data, _log),
    do: {:noop, []}
end
