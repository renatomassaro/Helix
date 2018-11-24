defmodule Helix.Cache.Local do

  alias Helix.Network.Model.Connection
  alias Helix.Network.Model.Tunnel
  alias Helix.Network.Query.Tunnel, as: TunnelQuery
  alias Helix.Server.Model.Server
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Cache.Local.Shard, as: LocalCacheShard

  def get_server(server_id = %Server.ID{}) do
    on_not_found = fn ->
      server_id
      |> ServerQuery.fetch()
      |> populate(server_id, :server)
    end

    generic_get(server_id, :server, on_not_found)
  end

  def get_tunnel(tunnel_id = %Tunnel.ID{}) do
    on_not_found = fn ->
      tunnel_id
      |> TunnelQuery.fetch()
      |> populate(tunnel_id, :tunnel)
    end

    generic_get(tunnel_id, :tunnel, on_not_found)
  end

  def get_connection(connection_id = %Connection.ID{}) do
    on_not_found = fn ->
      connection_id
      |> TunnelQuery.fetch_connection()
      |> populate(connection_id, :connection)
    end

    generic_get(connection_id, :connection, on_not_found)
  end

  defp on_not_found(fun, id, type) do
    fun.(id)
    |> populate(id, type)
  end

  defp generic_get(id, type, on_not_found) do
    case LocalCacheShard.dispatch(id, :get_, type, [id]) do
      nil ->
        on_not_found.()

      :nx ->
        nil

      hit ->
        hit
    end
  end

  defp populate(result, id, type) do
    LocalCacheShard.dispatch(id, :put_, type, [id, result]) 

    result
  end
end
