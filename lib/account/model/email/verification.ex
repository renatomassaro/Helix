defmodule Helix.Account.Model.Email.Verification do
  @moduledoc """
  The `Email.VerificationQueue` holds information about accounts who are pending
  email verification.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias HELL.DateUtils
  alias HELL.Password
  alias Helix.Account.Model.Account

  @type t ::
    %__MODULE__{
      account_id: Account.id,
      key: key,
      creation_date: DateTime.t
    }

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @type key :: String.t

  @type creation_params ::
    %{
      account_id: Account.id
    }

  @creation_fields [:account_id]
  @required_fields [:account_id, :key, :creation_date]

  @primary_key false
  schema "email_verifications" do
    field :key, :string,
      primary_key: true
    field :account_id, id(:account)

    field :creation_date, :utc_datetime

    belongs_to :account, Account,
      references: :account_id,
      foreign_key: :account_id,
      define_field: false
  end

  @spec create_changeset(creation_params) ::
    changeset
  def create_changeset(creation_params) do
    %__MODULE__{}
    |> cast(creation_params, @creation_fields)
    |> put_key()
    |> put_defaults()
    |> validate_required(@required_fields)
  end

  defp put_key(changeset),
    do: put_change(changeset, :key, Password.generate(:verification_key))

  defp put_defaults(changeset),
    do: put_change(changeset, :creation_date, DateUtils.utc_now(:second))

  query do

    alias Helix.Account.Model.Account
    alias Helix.Account.Model.Email

    @spec by_key(Queryable.t, Email.Verification.key) ::
      Queryable.t
    def by_key(query \\ Email.Verification, key),
      do: where(query, [ev], ev.key == ^key)

    @spec by_account_id(Queryable.t, Account.account_id) ::
      Queryable.t
    def by_account_id(query \\ Email.Verification, account_id),
      do: where(query, [ev], ev.account_id == ^account_id)

    def join_account(query) do
      from email_verification in query,
        inner_join: account in assoc(email_verification, :account),
        preload: [:account]
    end
  end
end
