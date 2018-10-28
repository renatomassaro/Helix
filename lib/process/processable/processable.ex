defmodule Helix.Process.Processable do
  @moduledoc """
  Process.Processable is the core definition of a process' behavior. Among other
  things, it specifies what should happen when a process completes, and what
  should happen if the process gets killed.

  It is the complete specification of how a process should react to signals.

  Due to our event-driven architecture, reactions to process completion/abortion
  should be made on the form of events, so as much as possible a Processable
  callback should never perform a direct action, always relying on events to
  perform side-effects.
  """

  import HELL.Macros.Docp

  alias Helix.Event
  alias Helix.Process.Model.Process

  @type t :: struct

  @typedoc """
  The actions below are valid actions that will be performed on the process if
  they are returned on one of the callbacks below.

  ## :delete

  Obliterate the process, forever.

  Once this happens, a `ProcessDeletedEvent` is emitted.

  ## :pause

  Pauses a process.

  Emits `ProcessPausedEvent`.

  If the process is already paused, it remains paused (it's idempotent). In that
  case, however, the `ProcessPausedEvent` is not emitted.

  ## :resume

  Resumes a process.

  Emits `ProcessResumedEvent`.

  If the process is already resumed, it remains resumed (it's idempotent). In
  that case, however, the `ProcessResumedEvent` is not emitted.

  ## :renice

  Modifies the priority of the event.

  Emits `ProcessPriorityChangedEvent`

  ## :restart

  Resets any work the process may have done, and starts from scratch.

  Not implemented yet.

  ## :retarget

  Modify the target of a process, potentially changing its resources and/or
  relevant objects. Commonly used with recursive processes.

  ## {:SIGKILL, <reason>}

  Sends a SIGKILL to itself, with the given reason as a parameter.

  Emits a `ProcessSignaledEvent`. 

  Later on, the process *might* be killed. Depends on how it implements the
  `on_kill` callback.

  ## :SIG_RETARGET

  Sends a SIG_RETARGET to itself

  Later on, the process *might* change. Depends on how it implements the
  `on_retarget` callback.

  ## :noop

  Makes a lot of nada.

  Does not emit anything.
  """
  @type action ::
    :delete
    | :pause
    | :resume
    | :renice
    | :restart
    | {:retarget, Process.retarget_changes}
    | {:SIGKILL, Process.kill_reason}
    | :SIG_RETARGET
    | :noop

  @signal_map %{
    SIGTERM: :on_complete,
    SIGKILL: :on_kill,
    SIG_RETARGET: :on_retarget,
    SIG_SRC_CONN_DELETED: :on_source_connection_closed,
    SIG_TGT_CONN_DELETED: :on_target_connection_closed,
    SIG_TGT_LOG_REVISED: :on_target_log_revised,
    SIG_TGT_LOG_RECOVERED: :on_target_log_recovered,
    SIG_TGT_LOG_DESTROYED: :on_target_log_destroyed
  }

  @spec signal_handler(Process.signal, Process.t, Process.signal_params) ::
    {action, [Event.t]}

  for {signal, callback} <- @signal_map do

    @doc false
    def signal_handler(unquote(signal), process, args) do
      process
      |> get_processable_hembed()
      |> deliver(unquote(callback), process, listify(args))
      |> add_fingerprint(process)
    end

  end

  @doc false
  @spec after_read_hook(t) ::
    t
  def after_read_hook(process_data) do
    processable = get_processable_hembed(process_data)

    if :after_read_hook in apply(processable, :signals_handled, []) do
      apply(processable, :after_read_hook, [process_data])
    else
      process_data
    end
  end

  defp deliver(processable, signal, process, args) do
    # Process implements callback for `signal`
    if signal in apply(processable, :signals_handled, []) do
      apply(processable, signal, [process, process.data | args])

    # Process does not implement callback for `signal`, so we'll use the default
    else
      default_handler(signal, [process, process.data | args])
    end
  end

  docp """
  Save the `process_id` on the events that will be emitted. This may be used
  later by TOPHandler to make sure that some signals are filtered, avoiding that
  a process receives the signal of a side-effect performed by the process
  itself.
  """
  defp add_fingerprint({action, events}, %{process_id: process_id}) do
    events = Enum.map(events, &(Event.set_process_id(&1, process_id)))

    {action, events}
  end

  defp listify(args),
    do: Enum.map(args, fn {_, v} -> v end)

  defp default_handler(signal, args),
    do: apply(__MODULE__.Defaults, signal, args)

  defp get_processable_hembed(%Process{data: process_data}),
    do: get_processable_hembed(process_data)
  defp get_processable_hembed(process),
    do: Module.concat(process.__struct__, Processable)
end
