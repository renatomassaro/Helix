defmodule Helix.Session.Model.SSE.Queue do

  use Ecto.Schema

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias Helix.Session.Model.Session

  @type message_id :: integer

  @type t ::
    %__MODULE__{
      message_id: message_id,
      session_id: Session.id,
      node_id: atom,
      creation_date: DateTime.t
    }

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @type creation_params :: %{
    message_id: integer,
    session_id: Session.id,
    node_id: atom
  }

  @creation_fields [:message_id, :session_id, :node_id]
  @required_fields [:message_id, :session_id, :node_id, :creation_date]

  @id_range -32_768..32_767

  @primary_key false
  schema "sse_queue" do
    field :message_id, :integer,
      primary_key: true

    field :session_id, Ecto.UUID
    field :node_id, :string

    field :creation_date, :utc_datetime
  end

  @spec create_changeset(creation_params) ::
    changeset
  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> put_change(:creation_date, DateTime.utc_now())
    |> validate_required(@required_fields)
  end

  @spec generate_message_id() ::
    message_id
  def generate_message_id,
    do: Enum.random(@id_range)

  query do

    alias Helix.Session.Model.Session

    @spec in_id(Queryable.t, [Queue.message_id]) ::
      Queryable.t
    def in_id(query \\ Queue, id_list),
      do: where(query, [sq], sq.message_id in ^id_list)

    @spec by_node(Queryable.t, term) ::
      Queryable.t
    def by_node(query \\ Queue, id),
      do: where(query, [sq], sq.node_id == ^id)

    @spec by_session(Queryable.t, Session.id) ::
      Queryable.t
    def by_session(query \\ Queue, id),
      do: where(query, [sq], sq.session_id == ^id)

    @spec before_date(Queryable.t, DateTime.t) ::
      Queryable.t
    def before_date(query, date),
      do: where(query, [sq], sq.creation_date <= ^date)
  end
end
