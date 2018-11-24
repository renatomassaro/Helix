defmodule Helix.Network.Public.Index do

  alias Helix.Server.Model.Server
  alias Helix.Network.Query.Tunnel, as: TunnelQuery

  @type index ::
    term

  @type rendered_index ::
    term

  # @spec index(:gateway, Server.id) ::
  #   index
  def index(:gateway, server_id) do
    %{
      origin: TunnelQuery.tunnels_originating(server_id),
      target: []
    }
  end

  def index(:remote, endpoint_id, gateway_id) do
    %{
      origin: [],
      target: TunnelQuery.tunnels_targeting(gateway_id, endpoint_id)
    }
  end

  # @spec render_index(index) ::
  #   term
  def render_index(_, _index) do
    []
  end
end
