defmodule Helix.Test.Process.Helper.Processable do

  alias Helix.Process.Processable

  def after_read_hook(process_data),
    do: Processable.after_read_hook(process_data)

  def complete(process, reason \\ :completed),
    do: Processable.signal_handler(:SIGTERM, process, %{reason: reason})

  def kill(process, reason),
    do: Processable.signal_handler(:SIGKILL, process, %{reason: reason})

  def retarget(process),
    do: Processable.signal_handler(:SIG_RETARGET, process, %{})
end
