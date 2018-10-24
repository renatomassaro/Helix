defmodule Helix.Software.Event.Handler.Virus do

  use Hevent.Handler

  alias Helix.Event
  alias Helix.Software.Action.Virus, as: VirusAction

  alias Helix.Software.Event.File.Install.Processed,
    as: FileInstallProcessedEvent
  alias Helix.Software.Event.Virus.Collect.Processed,
    as: VirusCollectProcessedEvent

  @doc """
  Handles the completion of `FileInstallProcess` when the target file is a
  virus.

  Performs a noop if the target file is not a virus.

  Emits: `VirusInstalledEvent`, `VirusInstallFailedEvent`
  """
  handle FileInstallProcessedEvent,
    on: %FileInstallProcessedEvent{backend: :virus}
  do
    case VirusAction.install(event.file, event.entity_id) do
      {:ok, virus, events} ->
        Event.emit(events, from: event)

        {:ok, virus}

      {:error, reason, events} ->
        Event.emit(events, from: event)

        {:error, reason}
    end
  end

  handle FileInstallProcessedEvent,
    on: %FileInstallProcessedEvent{backend: _}
  do
    :noop
  end

  @doc """
  Handles the completion of `VirusCollectProcess`.

  Emits: `VirusCollectedEvent`
  """
  handle VirusCollectProcessedEvent do
    case VirusAction.collect(event.file, event.payment_info) do
      {:ok, events} ->
        Event.emit(events, from: event)

        :ok

      {:error, events} ->
        Event.emit(events, from: event)

        :error
    end
  end
end
