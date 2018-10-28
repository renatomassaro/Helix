use Helix.Process

process Helix.Software.Process.File.Transfer do
  @moduledoc """
  SoftwareFileTransferProcess is the process responsible for transferring files
  from one storage to another. It currently implements the `download`, `upload`
  and `pftp_download` backends.

  Its process data consists basically of which backend is being used, and what
  storage the file is being transferred to. All other information, e.g. which
  file is being transferred, is already present on the standard process data.
  """

  alias Helix.Network.Model.Bounce
  alias Helix.Network.Model.Network
  alias Helix.Software.Model.File
  alias Helix.Software.Model.Storage
  alias __MODULE__, as: FileTransferProcess

  process_struct [:type, :destination_storage_id, :connection_type]

  @type t :: %__MODULE__{
    type: transfer_type,
    destination_storage_id: Storage.id,
    connection_type: connection_type
  }

  @type resources ::
    %{
      objective: objective,
      l_dynamic: [:dlk] | [:ulk],
      r_dynamic: [:ulk] | [:dlk],
      static: map
    }

  @type objective ::
    %{dlk: resource_usage}
    | %{ulk: resource_usage}

  @type process_type :: :file_download | :file_upload
  @type transfer_type :: :download | :upload
  @type connection_type :: :ftp | :public_ftp

  @type creation_params :: %{
    type: transfer_type,
    connection_type: connection_type,
    destination_storage_id: Storage.id
  }

  @type executable_meta :: %{
    file: File.t,
    type: process_type,
    network_id: Network.id,
    bounce: Bounce.idt | nil
  }

  @type resources_params :: %{
    type: transfer_type,
    file: File.t,
    network_id: Network.id
  }

  @spec new(creation_params, executable_meta) ::
    t
  def new(params = %{destination_storage_id: %Storage.ID{}}, _) do
    %__MODULE__{
      type: params.type,
      destination_storage_id: params.destination_storage_id,
      connection_type: params.connection_type
    }
  end

  processable do
    @moduledoc """
    Processable handler for SoftwareFileTransferProcess

    All events emitted here are generic, i.e. they are not directly related to
    the backend using FileTransferProcess.

    For example, FileTransferProcessedEvent is emitted on conclusion, regardless
    if the backend is `download`, `upload` or `pftp_download`
    """

    alias Helix.Server.Model.Server
    alias Helix.Software.Model.Storage

    alias Helix.Software.Event.File.Transfer.Aborted,
      as: FileTransferAbortedEvent
    alias Helix.Software.Event.File.Transfer.Processed,
      as: FileTransferProcessedEvent

    @doc """
    Emits `FileTransferProcessedEvent.t` when process completes.
    """
    def on_complete(process, data, _reason) do
      {from_id, to_id} = get_servers_context(data, process)
      event = FileTransferProcessedEvent.new(process, data, from_id, to_id)

      {:delete, [event]}
    end

    @doc """
    Emits `FileTransferAbortedEvent.t` when/if process gets killed.
    """
    def on_kill(process, data, _reason) do
      reason = :killed
      {from_id, to_id} = get_servers_context(data, process)

      event =
        FileTransferAbortedEvent.new(process, data, from_id, to_id, reason)

      {:delete, [event]}
    end

    @spec get_servers_context(data :: term, process :: term) ::
      context :: {from_server :: Server.id, to_server :: Server.id}
    defp get_servers_context(%{type: :download}, process),
      do: {process.target_id, process.gateway_id}
    defp get_servers_context(%{type: :upload}, process),
      do: {process.gateway_id, process.target_id}

    def after_read_hook(data) do
      %FileTransferProcess{
        type: String.to_existing_atom(data.type),
        destination_storage_id: Storage.ID.cast!(data.destination_storage_id),
        connection_type: String.to_existing_atom(data.connection_type)
      }
    end
  end

  resourceable do
    @moduledoc """
    Sets the objectives to FileTransferProcess
    """

    alias Helix.Software.Factor.File, as: FileFactor

    @type factors ::
      %{
        file: %{size: FileFactor.fact_size}
      }

    @doc """
    We only need to know the file size to figure out the process objectives.
    """
    get_factors(params) do
      factor Helix.Software.Factor.File, params, only: :size
    end

    @doc false
    def network_id(_, %{network_id: network_id}),
      do: network_id

    @doc """
    Uses the downlink resource during download.
    """
    def dlk(f, %{type: :download}),
      do: f.file.size
    def dlk(_, %{type: :upload}),
      do: 0

    @doc """
    Uses the uplink resource during upload.
    """
    def ulk(f, %{type: :upload}),
      do: f.file.size
    def ulk(_, %{type: :download}),
      do: 0

    @doc false
    def static do
      %{
        paused: %{ram: 10},
        running: %{ram: 20}
      }
    end

    @doc false
    def dynamic(%{type: :download}),
      do: [:dlk]
    def dynamic(%{type: :upload}),
      do: [:ulk]

    @doc false
    def r_dynamic(%{type: :download}),
      do: [:ulk]
    def r_dynamic(%{type: :upload}),
      do: [:dlk]
  end

  executable do
    @moduledoc """
    Defines how FileTransferProcess should be executed.
    """

    alias Helix.Network.Model.Bounce
    alias Helix.Network.Model.Network
    alias Helix.Software.Model.File

    @type meta ::
      %{
        file: File.t,
        type: FileTransferProcess.process_type,
        network_id: Network.id,
        bounce: Bounce.idt | nil
      }

    @doc false
    def resources(_, _, params, meta, _) do
      %{
        type: params.type,
        file: meta.file,
        network_id: meta.network_id
      }
    end

    @doc false
    def target_file(_gateway, _target, _params, %{file: file}, _),
      do: file

    @doc false
    def source_connection(_gateway, _target, params, _, _),
      do: {:create, params.connection_type}
  end

  viewable do

    @doc false
    def render_data(process) do
      %{
        connection_type: to_string(process.data.connection_type),
        storage_id: to_string(process.data.destination_storage_id),
      }
    end
  end
end
