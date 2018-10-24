defmodule Helix.Log.Event.Handler.Log do
  @moduledoc false

  use Hevent.Handler

  alias Helix.Event
  alias Helix.Process.Action.Flow.Process, as: ProcessFlow
  alias Helix.Log.Action.Log, as: LogAction
  alias Helix.Log.Model.Log
  alias Helix.Log.Query.Log, as: LogQuery

  alias Helix.Log.Event.Forge.Processed, as: LogForgeProcessedEvent
  alias Helix.Log.Event.Recover.Processed, as: LogRecoverProcessedEvent

  @doc """
  Handler called right after a `LogForgeProcess` has completed. It will then
  either create a new log out of thin air, or edit an existing log.

  Emits: `LogCreatedEvent`, `LogRevisedEvent`
  """
  handle LogForgeProcessedEvent, on: %LogForgeProcessedEvent{action: :create} do
    # `action` is `:create`, so we'll create a new log out of thin air!
    result =
      LogAction.create(
        event.server_id, event.entity_id, event.log_info, event.forger_version
      )

    with {:ok, _, events} <- result do
      Event.emit(events, from: event)
    end
  end

  handle LogForgeProcessedEvent, on: %LogForgeProcessedEvent{action: :edit} do
    # `action` is `:edit`, so we'll stack up a revision on an existing log
    revise = fn log ->
      LogAction.revise(
        log, event.entity_id, event.log_info, event.forger_version
      )
    end

    with \
      log = %Log{} <- LogQuery.fetch(event.target_log_id),
      {:ok, _, events} <- revise.(log)
    do
      Event.emit(events, from: event)
    end
  end

  @doc """
  Handler called right after a `LogRecoverProcess` has completed. We check
  whether the log it was working on (if any) has any revisions we can pop out of
  the stack.

  If the `target_log_id` is nil, it means the process have been working on a
  log that is already on its original state, so there's nothing we can do other
  than send a SIG_RETARGET signal to the process.

  Otherwise, we pop the revision out and send the SIG_RETARGET signal.
  """
  handle LogRecoverProcessedEvent,
    on: %LogRecoverProcessedEvent{target_log_id: nil}
  do
    sigretarget(event)
  end

  handle LogRecoverProcessedEvent do
    with \
      log = %Log{} <- LogQuery.fetch(event.target_log_id),
      {:ok, _, events} <- LogAction.recover(log, event.entity_id)
    do
      Event.emit(events, from: event)
    end

    sigretarget(event)
  end

  defp sigretarget(event = %LogRecoverProcessedEvent{}) do
    event
    |> Event.get_process()
    |> ProcessFlow.signal(:SIG_RETARGET)
  end
end
