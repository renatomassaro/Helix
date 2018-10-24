defmodule Helix.Network.Event.Connection do

  import Hevent

  event Started do
    @moduledoc false

    alias Helix.Event
    alias Helix.Entity.Query.Entity, as: EntityQuery
    alias Helix.Network.Model.Connection
    alias Helix.Network.Model.Tunnel
    alias Helix.Network.Query.Tunnel, as: TunnelQuery

    @type t :: %__MODULE__{
      connection: Connection.t,
      tunnel: Tunnel.t,
      type: Connection.type
    }

    event_struct [:connection, :tunnel, :type]

    @spec new(Connection.t) ::
      t
    def new(connection = %Connection{}) do
      tunnel = TunnelQuery.get_tunnel(connection)

      %__MODULE__{
        connection: connection,
        tunnel: tunnel,
        type: connection.connection_type
      }
      |> Event.set_bounce_id(tunnel.bounce_id)
    end

    trigger Loggable do

      @doc """
      Gateway: "localhost logged into $first_ip as root"
      Endpoint: "$last_ip logged in as root"
      """
      def log_map(event = %_{type: :ssh}) do
        entity = EntityQuery.fetch_by_server(event.tunnel.gateway_id)

        %{
          event: event,
          entity_id: entity.entity_id,
          gateway_id: event.tunnel.gateway_id,
          endpoint_id: event.tunnel.target_id,
          network_id: event.tunnel.network_id,
          type_gateway: :remote_login_gateway,
          data_gateway: %{ip: "$first_ip"},
          type_endpoint: :remote_login_endpoint,
          data_endpoint: %{ip: "$last_ip"},
          data_both: %{network_id: event.tunnel.network_id}
        }
      end

      def log_map(e) do
        %{}
      end
    end
  end

  event Closed do
    @moduledoc false

    alias Helix.Network.Model.Connection
    alias Helix.Network.Model.Tunnel
    alias Helix.Network.Query.Tunnel, as: TunnelQuery

    @type t :: %__MODULE__{
      connection: Connection.t,
      tunnel: Tunnel.t,
      type: Connection.type,
      reason: Connection.close_reasons
    }

    event_struct [:connection, :tunnel, :type, :reason]

    @spec new(Connection.t, Connection.close_reasons) ::
      t
    def new(connection = %Connection{}, reason \\ :normal) do
      %__MODULE__{
        connection: connection,
        tunnel: TunnelQuery.get_tunnel(connection),
        reason: reason,
        type: connection.connection_type
      }
    end
  end
end
