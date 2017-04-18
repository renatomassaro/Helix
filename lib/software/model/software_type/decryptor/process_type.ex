# FIXME: OTP20
defmodule Software.Decryptor.ProcessType do

  @enforce_keys [:storage_id, :target_file_id, :scope]
  defstruct [:storage_id, :target_file_id, :scope]

  defimpl Helix.Process.Model.Process.ProcessType do

    alias Helix.Software.Model.SoftwareType.Decryptor.ProcessConclusionEvent

    # The only value that is dynamic (ie: the more allocated, the faster the
    # process goes) is cpu
    def dynamic_resources(%{}),
      do: [:cpu]

    def conclusion(data, process) do
      process =
        process
        |> Ecto.Changeset.change()
        |> Map.put(:action, :delete)

      events = event(data, process, :completed)

      {process, events}
    end

    def event(data, process, :completed) do
      event = %ProcessConclusionEvent{
        target_file_id: data.target_file_id,
        target_server_id: process.target_server_id,
        storage_id: data.storage_id,
        scope: data.scope
      }

      [event]
    end

    def event(_, _, _) do
      []
    end
  end
end
