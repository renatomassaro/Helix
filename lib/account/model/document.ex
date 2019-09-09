defmodule Helix.Account.Model.Document do

  use Ecto.Schema

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias HELL.DateUtils
  alias __MODULE__, as: Document

  @type t :: %__MODULE__{
    document_id: id,
    revision_id: revision_id,
    current: boolean,
    content_raw: content,
    content_html: content,
    diff_raw: diff,
    diff_html: diff,
    update_reason: reason,
    publish_date: DateTime.t,
    enforced_from: DateTime.t,
    enforced_until: DateTime.t | nil
  }

  @type id :: :tos | :pp
  @type revision_id :: pos_integer
  @type content :: binary
  @type diff :: binary
  @type reason :: binary

  @type creation_params ::
    %{
      document_id: id,
      revision_id: revision_id,
      content_raw: content,
      content_htm: content,
      diff_raw: diff,
      diff_html: diff,
      update_reason: reason,
      enforced_from: DateTime.t
    }

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @creation_fields [
    :document_id,
    :revision_id,
    :content_raw,
    :content_html,
    :diff_raw,
    :diff_html,
    :update_reason,
    :enforced_from
  ]

  @required_fields [
    :document_id,
    :revision_id,
    :content_raw,
    :content_html,
    :diff_raw,
    :diff_html,
    :update_reason,
    :publish_date,
    :enforced_from
  ]

  @primary_key false
  schema "documents" do
    field :document_id, Document.Enum,
      primary_key: true
    field :revision_id, :integer,
      primary_key: true

    field :current, :boolean

    field :content_raw, :string
    field :content_html, :string
    field :diff_raw, :string
    field :diff_html, :string
    field :update_reason, :string

    field :publish_date, :utc_datetime
    field :enforced_from, :utc_datetime
    field :enforced_until, :utc_datetime
  end

  @spec create_changeset(creation_params) ::
    changeset
  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> put_defaults()
    |> validate_required(@required_fields)
  end

  def set_as_current(document) do
    document
    |> put_change(:current, true)
  end

  def expired?(%Document{enforced_until: nil}),
    do: false
  def expired?(%Document{enforced_until: until}) when not is_nil(until),
    do: true

  defp put_defaults(changeset) do
    changeset
    |> put_change(:publish_date, DateUtils.utc_now(:second))
  end

  query do

    alias Helix.Account.Model.Document

    @spec by_pk(Queryable.t, Document.id, Document.revision_id) ::
      Queryable.t
    def by_pk(query \\ Document, doc_id, rev_id) do
      where(query, [d], d.document_id == ^doc_id and d.revision_id == ^rev_id)
    end

    @spec by_current(Queryable.t, Document.id) ::
      Queryable.t
    def by_current(query \\ Document, document_id),
      do: where(query, [d], d.document_id == ^document_id and d.current == true)
  end
end
