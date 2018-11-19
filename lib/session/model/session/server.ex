defmodule Helix.Session.Model.Session.Server do

  use Ecto.Schema

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias Helix.Server.Model.Server
  alias Helix.Session.Model.Session

  @type t :: %__MODULE__{
    session_id: Session.id,
    server_id: Server.id,
    server_data: term
  }

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @type creation_params :: %{
    session_id: Session.id,
    server_id: Server.id,
    socket_data: term,
    account_data: term
  }

  @creation_fields [:session_id, :server_id, :server_data]
  @required_fields @creation_fields

  @primary_key false
  schema "sessions_servers" do
    field :session_id, Ecto.UUID,
      primary_key: true

    field :server_id, id(:server),
      primary_key: true

    field :server_data, :map

    has_one :session, Session,
      foreign_key: :session_id,
      references: :session_id,
      on_delete: :delete_all
  end

  @spec create_changeset(creation_params) ::
    changeset
  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> validate_required(@required_fields)
  end
end
