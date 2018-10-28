use Helix.Process

process Helix.Universe.Bank.Process.Bank.Transfer do

  alias Helix.Universe.Bank.Model.BankTransfer

  process_struct [:transfer_id, :amount]

  @process_type :wire_transfer

  @type t ::
    %__MODULE__{
      transfer_id: BankTransfer.id,
      amount: BankTransfer.amount
    }

  @type creation_params ::
    %{
      transfer: BankTransfer.t
    }

  @type executable_meta :: map

  @type objective :: %{cpu: resource_usage}

  @type resources :: %{
    objective: objective,
    static: map,
    l_dynamic: [],
    r_dynamic: []
  }

  @type resources_params ::
    %{
      transfer: BankTransfer.t
    }

  @spec new(creation_params, executable_meta) ::
    t
  def new(%{transfer: transfer = %BankTransfer{}}, _) do
    %__MODULE__{
      transfer_id: transfer.transfer_id,
      amount: transfer.amount
    }
  end

  processable do

    alias Helix.Universe.Bank.Event.Bank.Transfer.Aborted,
      as: BankTransferAbortedEvent
    alias Helix.Universe.Bank.Event.Bank.Transfer.Processed,
      as: BankTransferProcessedEvent

    @doc false
    def on_complete(process, data, _reason) do
      event = BankTransferProcessedEvent.new(process, data)

      {:delete, [event]}
    end

    @doc false
    def on_kill(process, data, _reason) do
      event = BankTransferAbortedEvent.new(process, data)

      {:delete, [event]}
    end
  end

  resourceable do

    @type factors :: term

    get_factors(%{transfer: _}) do
    end

    # TODO: Use Time, not CPU #364
    def cpu(_, %{transfer: transfer}) do
      transfer.amount
    end

    def dynamic do
      []
    end

    # TODO: Add ResourceTime; specify to the size of the transfer. #364
    def static do
      %{
        paused: %{ram: 50},
        running: %{ram: 100}
      }
    end
  end

  executable do

    alias Helix.Network.Model.Network
    alias Helix.Network.Model.Tunnel

    @type meta ::
      %{
        network_id: Network.id | nil,
        bounce: Tunnel.bounce
      }

    @doc false
    def resources(_gateway, _atm, %{transfer: transfer}, _meta, _),
      do: %{transfer: transfer}

    @doc false
    def source_connection(_gateway, _atm, _, _, _),
      do: {:create, :wire_transfer}
  end
end
