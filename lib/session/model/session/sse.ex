defmodule Helix.Session.Model.Session.SSE do

  use Ecto.Schema

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias Helix.Session.Model.Session

  @type t ::
    %__MODULE__{
      session_id: Session.id,
      node_id: atom,
    }

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @type creation_params :: %{
    session_id: Session.id,
    node_id: atom
  }

  @creation_fields [:session_id, :node_id]
  @required_fields [:session_id, :node_id]

  @primary_key false
  schema "sessions_sse" do
    field :session_id, Ecto.UUID,
      primary_key: true
    field :node_id, HELL.Constant
  end

  @spec create_changeset(creation_params) ::
    changeset
  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> validate_required(@required_fields)
  end

  query do

    alias Helix.Session.Model.Session

    @spec by_id(Queryable.t, Session.id) ::
      Queryable.t
    def by_id(query \\ Session.SSE, id),
      do: where(query, [ss], ss.session_id == ^id)
  end
end
