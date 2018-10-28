defmodule Helix.Process.Executable.Utils do

  import HELL.Macros.Docp

  alias Helix.Event
  alias Helix.Network.Action.Flow.Tunnel, as: TunnelFlow
  alias Helix.Network.Model.Bounce
  alias Helix.Network.Model.Connection
  alias Helix.Network.Model.Network
  alias Helix.Network.Query.Tunnel, as: TunnelQuery
  alias Helix.Server.Model.Server
  alias Helix.Process.Model.Process

  @typep args :: list

  @spec merge_params(
    map,
    Connection.t | nil | %{connection_id: nil},
    Connection.t | nil | %{connection_id: nil})
  ::
    Process.creation_params
  def merge_params(params, nil, target_connection),
    do: merge_params(params, %{connection_id: nil}, target_connection)
  def merge_params(params, connection, nil),
    do: merge_params(params, connection, %{connection_id: nil})
  def merge_params(
    params,
    %{connection_id: src_connection_id},
    %{connection_id: tgt_connection_id})
  do
    params
    |> Map.put(:src_connection_id, src_connection_id)
    |> Map.put(:tgt_connection_id, tgt_connection_id)
  end

  @spec setup_connection(
    args,
    result :: {:create, Connection.type},
    origin :: Connection.t | nil,
    Event.relay)
  ::
    {:ok, Connection.t}
  docp """
  `setup_connection/5` handles whatever the user defined at
  `source_connection` and `target_connection` at the Process' Executable
  declaration.

  It may be one of:

  - {:create, type}: A new connection of type `type` will be created.
  - %Connection{} | %Connection.ID{}: This connection will be used (i.e.
    since the connection was given, we assume it already exists)
  - :same_origin: We'll reuse the connection given at the `origin` param
  - nil | :ok | :noop: No connection was specified
  """
  def setup_connection(
    [gateway, target, _, meta, _], {:create, type}, _, relay)
  do
    {:ok, _tunnel, connection} =
      create_connection(
        meta.network_id,
        gateway.server_id,
        target.server_id,
        meta.bounce,
        type,
        relay
      )

    {:ok, connection}
  end

  @spec setup_connection(
    args,
    Connection.idt,
    origin :: Connection.t | nil,
    Event.relay)
  ::
    {:ok, Connection.t}
  def setup_connection(_, connection = %Connection{}, _, _),
    do: {:ok, connection}
  def setup_connection(_, connection_id = %Connection.ID{}, _, _),
    do: {:ok, TunnelQuery.fetch_connection(connection_id)}

  @spec setup_connection(
    args,
    :same_origin,
    Connection.t,
    Event.relay)
  ::
    {:ok, Connection.t}
  def setup_connection(_, :same_origin, origin = %Connection{}, _),
    do: {:ok, origin}

  @spec setup_connection(
    args,
    nil | :ok | :noop,
    Connection.t | nil,
    Event.relay)
  ::
    {:ok, nil}
  def setup_connection(_, nil, _, _),
    do: {:ok, nil}
  def setup_connection(_, :ok, _, _),
    do: {:ok, nil}
  def setup_connection(_, :noop, _, _),
    do: {:ok, nil}

  @spec create_connection(
    Network.id,
    Server.id,
    Server.id,
    Bounce.idt | nil,
    Connection.type,
    Event.relay)
  ::
    {:ok, tunnel :: term, Connection.t}
  docp """
  Creates a new connection.
  """
  defp create_connection(
    network_id = %Network.ID{}, gateway_id, target_id, bounce, type, relay)
  do
    TunnelFlow.connect(
      network_id,
      gateway_id,
      target_id,
      bounce,
      {type, %{}},
      relay
    )
  end
end
