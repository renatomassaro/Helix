defmodule Helix.Session.Model.Session.Unsynced do

  use Ecto.Schema

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias HELL.Utils
  alias Helix.Account.Model.Account
  alias Helix.Session.Model.Session

  @type t :: %__MODULE__{
    session_id: Session.id,
    account_id: Account.id,
    expiration_date: DateTime.t
  }

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @type creation_params :: %{
    session_id: Session.id,
    account_id: Account.id
  }

  @creation_fields [:session_id, :account_id]
  @required_fields [:session_id, :account_id, :expiration_date]

  @expiration_ttl 60

  @primary_key false
  schema "sessions_unsynced" do
    field :session_id, Ecto.UUID,
      primary_key: true
    field :account_id, id(:account)

    field :expiration_date, :utc_datetime
  end

  @spec create_changeset(creation_params) ::
    changeset
  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> put_change(:expiration_date, Utils.date_after(@expiration_ttl))
    |> validate_required(@required_fields)
  end

  query do

    alias Helix.Session.Model.Session

    @spec by_id(Queryable.t, Session.id) ::
      Queryable.t
    def by_id(query \\ Session.Unsynced, id),
      do: where(query, [su], su.session_id == ^id)

    def filter_expired(query) do
      query
      |> where([su], su.expiration_date >= fragment("now() AT TIME ZONE 'UTC'"))
    end
  end
end
