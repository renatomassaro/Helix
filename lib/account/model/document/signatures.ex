defmodule Helix.Account.Model.Document.Signature do

  use Ecto.Schema

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias HELL.DateUtils
  alias HELL.IPv4
  alias Helix.Account.Model.Account
  alias Helix.Account.Model.Document

  @type t ::
    %__MODULE__{
      account_id: Account.id,
      document_id: Document.id,
      revision_id: Document.revision_id,
      signature_date: DateTime.t,
      ip_address: ip,
      user_agent: user_agent
    }

  @type info :: %{
    ip_address: ip,
    user_agent: user_agent
  }

  @type ip :: IPv4.t
  @type user_agent :: String.t

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @type creation_fields :: %{
    account_id: Account.id,
    document_id: Document.id,
    revision_id: Document.revision_id,
    ip_address: IPv4.t,
    user_agent: String.t
  }

  @creation_fields [
    :account_id,
    :document_id,
    :revision_id,
    :ip_address,
    :user_agent
  ]

  @required_fields [
    :account_id,
    :document_id,
    :revision_id,
    :signature_date,
    :ip_address,
    :user_agent
  ]

  @primary_key false
  schema "document_signatures" do
    field :account_id, id(:account),
      primary_key: true
    field :document_id, Document.Enum,
      primary_key: true
    field :revision_id, :integer,
      primary_key: true

    field :signature_date, :utc_datetime
    field :ip_address, IPv4
    field :user_agent, :string
  end

  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> put_defaults()
    |> validate_required(@required_fields)
  end

  defp put_defaults(changeset),
    do: put_change(changeset, :signature_date, DateUtils.utc_now(:second))

  query do

    alias Helix.Account.Model.Account
    alias Helix.Account.Model.Document

    @spec by_pk(Queryable.t, Account.id, Document.id, Document.revision_id) ::
      Queryable.t
    def by_pk(query \\ Document.Signature, acc_id, doc_id, rev_id) do
      where(
        query,
        [ds],
        ds.account_id == ^acc_id and
        ds.document_id == ^doc_id and
        ds.revision_id == ^rev_id
      )
    end

    @spec by_document(Queryable.t, Account.id, Document.id) ::
      Queryable.t
    def by_document(query \\ Document.Signature, acc_id, doc_id) do
      where(query, [ds], ds.account_id == ^acc_id and ds.document_id == ^doc_id)
    end

    @spec only(Queryable.t, pos_integer) ::
      Queryable.t
    def only(query, total),
      do: limit(query, ^total)
  end

  order do
    def by_most_recent_signature(query),
      do: order_by(query, [ds], desc: ds.signature_date)
  end
end
