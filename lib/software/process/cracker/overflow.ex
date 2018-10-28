use Helix.Process

process Helix.Software.Process.Cracker.Overflow do
  @moduledoc false

  alias Helix.Software.Model.File

  process_struct []

  @type t :: %__MODULE__{}

  @type creation_params :: %{}

  @type executable_meta ::
    %{
      cracker: File.t
    }

  @type objective :: %{cpu: resource_usage}

  @type resources ::
    %{
      objective: objective,
      static: map,
      l_dynamic: [:cpu],
      r_dynamic: []
    }

  @type resources_params ::
    %{
      cracker: File.t
    }

  @process_type :cracker_overflow

  @spec new(creation_params, executable_meta) ::
    t
  def new(_, _),
    do: %__MODULE__{}

  processable do

    alias Helix.Software.Event.Cracker.Overflow.Processed,
      as: OverflowProcessedEvent

    def on_complete(process, data, _reason) do
      event = OverflowProcessedEvent.new(process, data)

      {:delete, [event]}
    end
  end

  resourceable do

    alias Helix.Software.Factor.File, as: FileFactor
    alias Helix.Software.Model.File

    @type factors ::
      %{
        cracker: %{version: FileFactor.fact_version}
      }

    get_factors(%{cracker: cracker}) do
      factor FileFactor, %{file: cracker},
        only: :version,
        as: :cracker
    end

    # TODO: Testing and proper balance
    def cpu(f, _) do
      f.cracker.version.overflow
    end

    def dynamic,
      do: [:cpu]

    def static do
      %{
        paused: %{ram: 100},
        running: %{ram: 200}
      }
    end
  end

  executable do

    alias Helix.Network.Model.Connection
    alias Helix.Software.Model.File
    alias Helix.Process.Model.Process

    @type meta ::
      %{
        cracker: File.t,
        connection: Connection.t | nil,
        process: Process.t,
        ssh: Connection.t | nil
      }

    @doc false
    def resources(_, _, _, %{cracker: cracker}, _),
      do: %{cracker: cracker}

    @doc false
    def source_file(_gateway, _target, _params, %{cracker: cracker}, _),
      do: cracker

    @doc false
    def source_connection(_, _, _, %{ssh: ssh}, _),
      do: ssh

    @doc false
    def target_connection(_, _, _, %{connection: connection}, _),
      do: connection

    @doc false
    def target_process(_, _, _, %{process: process}, _),
      do: process
  end
end
