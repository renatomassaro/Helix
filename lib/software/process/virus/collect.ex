use Helix.Process

process Helix.Software.Process.Virus.Collect do
  @moduledoc """
  `VirusCollectProcess` is the process responsible for rewarding players money
  based on their active viruses.

  The process holds information about a single virus, so when collecting `n`
  viruses, `n` process (and `n` connections) will be created.

  This process is mostly a thin wrapper, as it should be. Handling of completion
  is performed by `VirusHandler` once `VirusCollectProcessedEvent` is fired.
  """

  alias Helix.Network.Model.Bounce
  alias Helix.Network.Model.Network
  alias Helix.Universe.Bank.Model.BankAccount
  alias Helix.Software.Model.File

  process_struct [:wallet]

  @process_type :virus_collect

  @type t ::
    %__MODULE__{
      wallet: term
    }

  @type resources ::
    %{
      objective: objective,
      l_dynamic: [:cpu],
      r_dynamic: [],
      static: map
    }

  @type objective ::
    %{cpu: resource_usage}

  @type creation_params ::
    %{
      wallet: term | nil,
      bank_account: BankAccount.t | nil
    }

  @type executable_meta ::
    %{
      virus: File.t,
      network_id: Network.id,
      bounce: Bounce.idt | nil
    }

  @type resources_params :: map

  @spec new(creation_params, executable_meta) ::
    t
  def new(%{wallet: wallet}, _) do
    %__MODULE__{
      wallet: wallet
    }
  end

  processable do

    alias Helix.Software.Event.Virus.Collect.Processed,
      as: VirusCollectProcessedEvent

    @doc false
    def on_complete(process, data, _reason) do
      event = VirusCollectProcessedEvent.new(process, data)

      {:delete, [event]}
    end
  end

  resourceable do

    @type factors :: map

    get_factors(_params) do
    end

    def cpu(_, _) do
      500
    end

    def static do
      %{
        paused: %{ram: 10},
        running: %{ram: 20}
      }
    end

    def dynamic,
      do: [:cpu]
  end

  executable do

    alias Helix.Network.Model.Bounce
    alias Helix.Network.Model.Network
    alias Helix.Software.Model.File

    @type meta ::
      %{
        virus: File.t,
        network_id: Network.id,
        bounce: Bounce.idt | nil
      }

    @doc false
    def source_file(_, _, _, %{virus: virus}, _),
      do: virus.file_id

    @doc false
    def source_connection(_, _, _, _, _),
      do: {:create, :virus_collect}

    @doc """
    There's no bank account when collecting the earnings of a `miner` virus. For
    any other virus, there must always have a bank account.
    """
    def target_bank_account(
      _, _, _, %{virus: %{software_type: :virus_miner}}, _)
    do
      nil
    end

    def target_bank_account(_, _, %{bank_account: bank_acc}, _, _),
      do: bank_acc
  end
end
