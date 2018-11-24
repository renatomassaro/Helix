defmodule Helix.Session.Model.Session do

  use Ecto.Schema

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias HELL.MapUtils
  alias HELL.DateUtils
  alias Helix.Account.Model.Account
  alias Helix.Entity.Model.Entity
  alias Helix.Network.Model.Bounce
  alias Helix.Network.Model.Connection
  alias Helix.Network.Model.Network
  alias Helix.Network.Model.Tunnel
  alias Helix.Server.Model.Server
  alias __MODULE__, as: Session

  @typep id :: term

  @type t :: %__MODULE__{
    session_id: id,
    account_id: Account.id,
    socket_data: term,
    account_data: term,
    expiration_date: DateTime.t
  }

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @type creation_params :: %{
    account_id: Account.id,
    socket_data: term,
    account_data: term
  }

  @creation_fields [
    :session_id,
    :account_id,
    :socket_data,
    :account_data,
    :expiration_date
  ]
  @required_fields @creation_fields

  @expiration_ttl 3600

  @primary_key false
  schema "sessions" do
    field :session_id, Ecto.UUID,
      primary_key: true

    field :account_id, id(:account)

    field :socket_data, :map
    field :account_data, :map

    field :expiration_date, :utc_datetime

    has_many :servers, Session.Server,
      foreign_key: :session_id,
      references: :session_id,
      on_delete: :delete_all

    has_one :sse, Session.SSE,
      foreign_key: :session_id,
      references: :session_id,
      on_delete: :delete_all
  end

  def create_session(
    session_id,
    %{socket: socket_data, account: account_data, servers: servers_data})
  do
    account_id = socket_data.account_id

    session_changeset =
      %{
        session_id: session_id,
        account_id: socket_data.account_id,
        socket_data: %{socket_data| session_id: session_id},
        account_data: account_data
      }
      |> create_changeset()

    servers_changeset =
      servers_data
      |> Enum.map(fn {server_id, server_data} ->
        %{
          session_id: session_id,
          server_id: server_id,
          server_data: server_data
        }
        |> Session.Server.create_changeset()
      end)

    %{
      session: session_changeset,
      servers: servers_changeset
    }
  end

  @spec create_changeset(creation_params) ::
    changeset
  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> put_change(:expiration_date, DateUtils.date_after(@expiration_ttl))
    |> validate_required(@required_fields)
    |> unique_constraint(:session_id, name: :sessions_pkey)
  end

  def generate_session_id,
    do: SecureRandom.uuid()

  def format(nil),
    do: nil
  def format(session) do
    servers_map =
      Enum.reduce(session.servers, %{}, fn server, acc ->
        Map.put(
          acc,
          to_string(server.server_id),
          format_server_data(server.server_data)
        )
      end)

    %{
      # Socket (root-level data)
      session_id: session.session_id,
      account_id: session.account_id,
      entity_id: Entity.ID.cast!(to_string(session.account_id)),
      client: String.to_existing_atom(session.socket_data["client"]),

      # Sub-maps
      account: session.account_data,
      servers: servers_map,
      context: %{},
    }
  end

  def format_tunnel(tunnel = %Tunnel{}),
    do: Map.take(tunnel, [:tunnel_id, :bounce_id, :network_id])
  def format_ssh(ssh = %Connection{}),
    do: Map.take(ssh, [:connection_id])

  defp format_server_data(server = %{"access" => "local"}) do
    gateway_data = %{
      server_id: Server.ID.cast!(server["server_id"]),
      entity_id: Entity.ID.cast!(server["entity_id"])
    }

    %{
      gateway: gateway_data,
      endpoint: gateway_data,
      access: :local
    }
  end

  defp format_server_data(data = %{"access" => "remote"}) do
    %{
      gateway: %{
        entity_id: Entity.ID.cast!(data["gateway"]["entity_id"]),
        server_id: Server.ID.cast!(data["gateway"]["server_id"]),
        ip: data["gateway"]["ip"]
      },
      endpoint: %{
        entity_id: Entity.ID.cast!(data["endpoint"]["entity_id"]),
        server_id: Server.ID.cast!(data["endpoint"]["server_id"]),
        ip: data["endpoint"]["ip"]
      },
      tunnel: %{
        tunnel_id: Tunnel.ID.cast!(data["tunnel"]["tunnel_id"]),
        network_id: Network.ID.cast!(data["tunnel"]["network_id"]),
        bounce_id: get_bounce_id(data["tunnel"]["bounce_id"])
      },
      ssh: %{
        connection_id: Connection.ID.cast!(data["ssh"]["connection_id"])
      },
      access: :remote
    }
  end

  defp get_bounce_id(nil),
    do: nil
  defp get_bounce_id(bounce_id = %Bounce.ID{}),
    do: Bounce.ID.cast!(bounce_id)

  query do

    @spec by_id(Queryable.t, Session.id) ::
      Queryable.t
    def by_id(query \\ Session, id),
      do: where(query, [s], s.session_id == ^id)

    def join_servers(query) do
      from s in query,
        preload: [:servers]
    end

    def join_session_sse(query) do
      from s in query,
        preload: [:session_sse]
    end

    def filter_expired(query) do
      query
      |> where([s], s.expiration_date >= fragment("now() AT TIME ZONE 'UTC'"))
    end
  end
end
