defmodule Helix.Test.Process.TOPHelper do

  alias Ecto.Changeset
  alias Helix.Process.Action.TOP, as: TOPAction
  alias Helix.Process.Model.Process
  alias Helix.Process.Query.Process, as: ProcessQuery
  alias Helix.Process.Repo, as: ProcessRepo

  alias Helix.Test.Process.Helper.Processable, as: ProcessableHelper

  @doc """
  Fetches a process from an event or its ID (binary or Helix.ID).
  """
  def fetch_process(event = %{event: "process_created"}),
    do: fetch_process(event.data.process_id)
  def fetch_process(process_id) when is_binary(process_id),
    do: fetch_process(Process.ID.cast!(process_id))
  def fetch_process(process_id = %Process.ID{}),
    do: ProcessQuery.fetch(process_id)

  @doc """
  Stops the TOP of a server.
  """
  def top_stop(_),
    do: top_stop()
  def top_stop,
    do: GenServer.stop(:event_timer)

  @doc """
  Completes the process, emitting the related events and removing from the db.
  """
  def force_completion(process_idtb, opts \\ [])
  def force_completion(process_idb, opts) when is_binary(process_idb),
    do: force_completion(process_idb |> Process.ID.cast!(), opts)
  def force_completion(process_id = %Process.ID{}, opts) do
    process_id
    |> ProcessQuery.fetch()
    |> force_completion(opts)
  end
  def force_completion(process = %Process{}, opts) do
    # Update the DB process entry, now it has magically reached its objective
    process
    |> Changeset.change()
    |> Changeset.put_change(:allocated, %{})  # Avoids `:waiting_alloc` status
    |> Changeset.put_change(:processed, Process.fmt_str(process.objective))
    |> ProcessRepo.update()

    # Force a recalque on the server
    if opts[:source] do
      TOPAction.recalque(process, source: opts[:source])
    else
      TOPAction.recalque(process)
    end
  end

  @doc """
  Runs the logic that would be ran if the process was completed, but does not
  actually modify the database, nor emit the conclusion events.
  """
  def soft_complete(process = %Process{}),
    do: ProcessableHelper.complete(process)

  @doc """
  Simulates the `kill` of a process, executing the `Processable` relevant code.
  It won't update the status on DB, nor emit events about the kill.
  """
  def soft_kill(process = %Process{}, reason \\ :killed),
    do: ProcessableHelper.kill(process, reason)
end
