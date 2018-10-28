use Helix.Process

process Helix.Universe.Bank.Process.Bank.Account.RevealPassword do

  alias Helix.Universe.Bank.Model.ATM
  alias Helix.Universe.Bank.Model.BankAccount
  alias Helix.Universe.Bank.Model.BankToken

  process_struct [:token_id, :atm_id, :account_number]

  @process_type :bank_reveal_password

  @type t ::
    %__MODULE__{
      token_id: BankToken.id,
      atm_id: ATM.id,
      account_number: BankAccount.account
    }

  @type creation_params ::
    %{
      token_id: BankToken.id,
      account: BankAccount.t
    }

  @type executable_meta :: map

  @type objective :: %{cpu: resource_usage}

  @type resources :: %{
    objective: objective,
    static: map,
    l_dynamic: [:cpu],
    r_dynamic: []
  }

  @type resources_params ::
    %{
      account: BankAccount.t
    }

  @spec new(creation_params, executable_meta) ::
    t
  def new(%{token_id: token_id, account: account = %BankAccount{}}, _) do
    %__MODULE__{
      token_id: token_id,
      atm_id: account.atm_id,
      account_number: account.account_number
    }
  end

  processable do

    alias Helix.Universe.Bank.Event.RevealPassword.Processed,
      as: RevealPasswordProcessedEvent

    @doc false
    def on_complete(process, data, _reason) do
      event = RevealPasswordProcessedEvent.new(process, data)

      {:delete, [event]}
    end
  end

  resourceable do

    @type factors :: term

    # TODO proper balance
    get_factors(%{account: _account}) do end

    def cpu(_, _) do
      1
    end

    def dynamic,
      do: [:cpu]
  end

  executable do

    @type meta :: %{}

    @doc false
    def resources(_, _, %{account: account}, _, _),
      do: %{account: account}
  end
end
