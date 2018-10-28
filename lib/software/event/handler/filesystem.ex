defmodule Helix.Software.Event.Handler.Filesystem do
  @moduledoc """
  This is the Hacker Experience's equivalent of `inotify(7)`
  """

  use Hevent.Handler

  alias Helix.Event
  alias Helix.Server.Model.Server
  alias Helix.Software.Model.File

  alias Helix.Software.Event.File.Added, as: FileAddedEvent
  alias Helix.Software.Event.File.Downloaded, as: FileDownloadedEvent
  alias Helix.Software.Event.File.Uploaded, as: FileUploadedEvent

  # New entries

  def handle_event(event = %FileDownloadedEvent{}),
    do: notify_new(event.file, event.to_server_id, event)

  def handle_event(event = %FileUploadedEvent{}),
    do: notify_new(event.file, event.to_server_id, event)

  # Existing entries being updated

  # Existing entries being removed
  # TODO FileDeletedEvent #384

  # Generic notifiers

  @spec notify_new(File.t, Server.id, Event.t) ::
    term
  defp notify_new(file = %File{}, server_id = %Server.ID{}, event) do
    file
    |> FileAddedEvent.new(server_id)
    |> Event.emit(from: event)
  end
end
