use Helix.Process

process Helix.Software.Process.File.Install do
  @moduledoc """
  `InstallFileProcess` is a generic process for installing files. The
  installation is specialized by the requested backend (e.g. installing viruses
  uses the `virus` backend). The backend defines what's supposed to happen once
  the process finishes, as well as how much resources it should take, etc.
  """

  alias Helix.Network.Model.Connection
  alias Helix.Network.Model.Network
  alias Helix.Network.Model.Tunnel
  alias Helix.Software.Model.File
  alias __MODULE__, as: FileInstallProcess

  alias Helix.Software.Event.File.Install.Processed,
    as: FileInstallProcessedEvent

  process_struct [:backend]

  @type process_type :: :install_virus
  @type backend :: :virus

  @type t ::
    %__MODULE__{
      backend: backend
    }

  @type resources ::
    %{
      objective: objective,
      l_dynamic: [:cpu],
      r_dynamic: [],
      static: map
    }

  @type creation_params :: %{backend: backend}
  @type executable_meta ::
    %{
      file: File.t,
      network_id: Network.id,
      bounce: Tunnel.bounce_id,
      ssh: Connection.ssh
    }

  @type objective :: %{cpu: resource_usage}

  @type resources_params ::
    %{
      file: File.t,
      backend: backend
    }

  @spec new(creation_params, executable_meta) ::
    t
  def new(%{backend: backend}, _meta) do
    %__MODULE__{
      backend: backend
    }
  end

  @spec get_backend(File.t) ::
    backend
  @doc """
  Based on the file to be installed, identify its backend.

  Currently only returns `:virus` as it's the only backend...
  """
  def get_backend(%File{}),
    do: :virus

  @spec get_process_type(creation_params, executable_meta) ::
    process_type
  def get_process_type(%{backend: :virus}, _),
    do: :install_virus

  processable do

    @doc false
    def on_complete(process, data, _reason) do
      event = FileInstallProcessedEvent.new(process, data)

      {:delete, [event]}
    end

    @doc false
    def after_read_hook(data) do
      %FileInstallProcess{
        backend: String.to_existing_atom(data.backend)
      }
    end
  end

  resourceable do

    alias Helix.Software.Factor.File, as: FileFactor

    @type factors :: term

    get_factors(%{file: file, backend: _}) do

      # Retrieves information about the file to be installed
      factor FileFactor, %{file: file},
        only: [:version, :size]
    end

    # TODO: Use time as a resource instead. #364
    def cpu(_, _),
      do: 300

    def dynamic,
      do: [:cpu]
  end

  executable do

    alias Helix.Software.Model.File

    @type meta ::
      %{
        file: File.t,
        type: FileInstallProcess.process_type,
        ssh: Connection.t | nil
      }

    @doc false
    def resources(_gateway, _target, %{backend: backend}, %{file: file}, _) do
      %{
        file: file,
        backend: backend
      }
    end

    @doc false
    def source_connection(_gateway, _target, _params, %{ssh: ssh}, _),
      do: ssh

    @doc false
    def target_file(_gateway, _target, _params, %{file: file}, _),
      do: file
  end
end
