defmodule Helix.Network.Model.Network do

  use Ecto.Schema
  use HELL.ID, field: :network_id

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias HELL.Constant
  alias __MODULE__, as: Network

  @type t :: %__MODULE__{
    network_id: id,
    name: name,
    type: type
  }

  @type name :: String.t
  @type type :: :internet | :story | :mission | :lan
  @type ip :: Network.Connection.ip

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @type nip :: %{
    network_id: id,
    ip: ip
  }

  @type creation_params ::
    %{
      name: name,
      type: type
    }

  @creation_fields [:name, :type]
  @required_fields [:name, :type]

  @network_types [:internet, :story, :mission, :lan]

  @internet %{
    __struct__: __MODULE__,
    name: "Internet",
    type: :internet,
    network_id: ID.cast!("::")
  }

  schema "networks" do
    field :network_id, id(),
      primary_key: true

    field :name, :string
    field :type, Constant
  end

  @spec create(creation_params) ::
    changeset
  def create(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> validate_inclusion(:type, possible_types())
    |> validate_required(@required_fields)
    |> put_pk(%{}, {:network, params.type})
  end

  @spec internet() ::
    t
  @doc """
  Returns the record for the global network called "Internet"
  """
  def internet,
    do: @internet

  @spec internet_id() ::
    id
  @doc """
  Returns the Internet's ID
  """
  def internet_id,
    do: @internet.network_id

  @spec possible_types() ::
    [type]
  defp possible_types,
    do: @network_types

  query do

    @spec by_id(Queryable.t, Network.idtb) ::
      Queryable.t
    def by_id(query \\ Network, id),
      do: where(query, [n], n.network_id == ^id)
  end
end
