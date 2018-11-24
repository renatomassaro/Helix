defmodule Helix.Entity.Model.Database.BankAccount do

  use Ecto.Schema

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias Ecto.UUID
  alias HELL.DateUtils
  alias HELL.IPv4
  alias Helix.Universe.Bank.Model.ATM
  alias Helix.Universe.Bank.Model.BankAccount
  alias Helix.Entity.Model.Entity

  @type changeset :: %Ecto.Changeset{data: %__MODULE__{}}

  @type t :: %__MODULE__{
    entity_id: Entity.idtb,
    atm_id: ATM.idtb,
    atm_ip: IPv4.t,
    account_number: BankAccount.account,
    password: String.t | nil,
    token: String.t | nil,
    notes: String.t | nil,
    known_balance: non_neg_integer | nil,
    last_login_date: DateTime.t | nil,
    last_update: DateTime.t
  }

  @type creation_params :: %{
    entity_id: Entity.idtb,
    atm_id: ATM.idtb,
    atm_ip: IPv4.t,
    account_number: BankAccount.account
  }

  @type update_params :: %{
    optional(:known_balance) => non_neg_integer,
    optional(:notes) => String.t,
    optional(:last_login_date) => DateTime.t,
    optional(:password) => String.t,
    optional(:token) => String.t
  }

  @creation_fields [:entity_id, :atm_id, :atm_ip, :account_number]
  @update_fields [:notes, :password, :token, :known_balance, :last_login_date]
  @required_creation [:entity_id, :atm_id, :atm_ip, :account_number]

  @notes_max_length 1024

  @primary_key false
  schema "database_bank_accounts" do
    field :entity_id, id(:entity),
      primary_key: true
    field :atm_id, id(:server),
      primary_key: true
    field :account_number, :integer,
      primary_key: true

    field :atm_ip, IPv4
    field :password, :string
    field :token, UUID
    field :known_balance, :integer
    field :notes, :string

    field :last_login_date, :utc_datetime
    field :last_update, :utc_datetime
  end

  @spec create_changeset(creation_params) ::
    Changeset.t
  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> validate_required(@required_creation)
    |> update_last_update()
  end

  @spec update_changeset(t, update_params) ::
    Changeset.t
  def update_changeset(struct, params) do
    struct
    |> cast(params, @update_fields)
    |> validate_length(:notes, max: @notes_max_length)
    |> update_last_update()
  end

  def update_password(struct, password) do
    struct
    |> change()
    |> put_change(:password, password)
  end

  defp update_last_update(changeset),
    do: put_change(changeset, :last_update, DateUtils.utc_now(:second))

  query do

    alias HELL.IPv4
    alias Helix.Universe.Bank.Model.ATM
    alias Helix.Universe.Bank.Model.BankAccount
    alias Helix.Entity.Model.Database
    alias Helix.Entity.Model.Entity

    @spec by_entity(Queryable.t, Entity.idtb) ::
      Queryable.t
    def by_entity(query \\ Database.BankAccount, id),
      do: where(query, [d], d.entity_id == ^id)

    @spec by_account(Queryable.t, ATM.idtb, BankAccount.account) ::
      Queryable.t
    def by_account(query \\ Database.BankAccount, atm, account),
      do: where(query, [d], d.atm_id == ^atm and d.account_number == ^account)

    @spec order_by_last_update(Queryable.t) ::
      Queryable.t
    def order_by_last_update(query),
      do: order_by(query, [d], desc: d.last_update)
  end
end
