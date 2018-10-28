use Helix.Process

process Helix.Software.Process.Cracker.Bruteforce do
  @moduledoc """
  The BruteforceProcess is launched when a user wants to figure out the root
  password of the target server (identified by `target_server_ip` and
  `target_id`).
  """

  alias Helix.Network.Model.Bounce
  alias Helix.Network.Model.Network
  alias Helix.Software.Model.File

  process_struct [:target_server_ip]

  @process_type :cracker_bruteforce

  @type t ::
    %__MODULE__{
      target_server_ip: Network.ip
    }

  @type creation_params ::
    %{
      target_server_ip: Network.ip
    }

  @type executable_meta ::
    %{
      cracker: File.t,
      network_id: Network.id,
      bounce: Bounce.t | nil
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
      cracker: File.t_of_type(:cracker),
      hasher: File.t_of_type(:hasher) | nil
    }

  @spec new(creation_params, executable_meta) ::
    t
  def new(%{target_server_ip: ip}, _) do
    %__MODULE__{
      target_server_ip: ip
    }
  end

  processable do
    @moduledoc """
    Defines the BruteforceProcess lifecycle behavior.
    """

    alias Helix.Network.Model.Network
    alias Helix.Software.Event.Cracker.Bruteforce.Processed,
      as: BruteforceProcessedEvent

    def on_complete(process, data, _reason) do
      event = BruteforceProcessedEvent.new(process, data)

      {:delete, [event]}
    end
  end

  resourceable do
    @moduledoc """
    Defines how long a BruteforceProcess should take, resource usage, etc.
    """

    alias Helix.Software.Factor.File, as: FileFactor
    alias Helix.Software.Model.File

    @type factors ::
      %{
        :cracker => %{version: FileFactor.fact_version},
        optional(:hasher) => %{version: FileFactor.fact_version}
      }

    @doc """
    At first all we care about is the attacker's Cracker version and the
    victim's Hasher version (if any). In the future we'll probably want to add
    extra factors, like Boost/Skills.
    """
    get_factors(%{cracker: cracker, hasher: hasher}) do

      # Retrieves information about the cracker
      factor FileFactor, %{file: cracker},
        only: :version,
        as: :cracker

      # Retrieves information about the target's hasher (if any)
      factor FileFactor, %{file: hasher},
        if: not is_nil(hasher),
        only: :version,
        as: :hasher
    end

    # TODO: Testing and proper balance
    @doc """
    BruteforceProcess only uses CPU.
    """
    def cpu(f, %{hasher: nil}),
      do: 10_000 - 100 * f.cracker.version.bruteforce

    def cpu(f, %{hasher: %File{}}),
      do: f.cracker.version.bruteforce * f.hasher.version.password

    def static do
      %{
        paused: %{ram: 20},
        running: %{ram: 50}
      }
    end

    def dynamic,
      do: [:cpu]
  end

  executable do
    @moduledoc """
    Defines how a BruteforceProcess should be executed.
    """

    alias Helix.Software.Model.File
    alias Helix.Software.Query.File, as: FileQuery

    @type meta ::
      %{
        cracker: File.t
      }

    @doc false
    def resources(_, target, _, %{cracker: cracker}, _) do
      hasher = FileQuery.fetch_best(target, :password)

      %{
        cracker: cracker,
        hasher: hasher
      }
    end

    @doc false
    def source_file(_gateway, _target, _params, %{cracker: cracker}, _),
      do: cracker

    @doc false
    def source_connection(_gateway, _target, _params, _meta, _),
      do: {:create, :cracker_bruteforce}
  end
end
