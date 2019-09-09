defmodule Helix.Server.Event.Server.Password do

  import Hevent

  event Acquired do
    @moduledoc """
    The `ServerPasswordAcquiredEvent` is fired after a Bruteforce attack has
    been completed, and the attacker discovered the target's server root
    password.
    """

    alias Helix.Entity.Model.Entity
    alias Helix.Network.Model.Network
    alias Helix.Server.Model.Server

    @type t :: %__MODULE__{
      entity_id: Entity.id,
      network_id: Network.id,
      server_id: Server.id,
      server_ip: Network.ip,
      password: Server.password
    }

    event_struct [
      :entity_id,
      :network_id,
      :server_id,
      :server_ip,
      :password
    ]

    @spec new(Entity.id, Server.id, Network.id, Network.ip, Server.password) ::
      t
    def new(entity_id, server_id, network_id, ip, password) do
      %__MODULE__{
        entity_id: entity_id,
        server_id: server_id,
        server_ip: ip,
        network_id: network_id,
        password: password
      }
    end

    trigger Publishable do

      use Helix.Event.Trigger.Publishable.Macros

      event_name :server_password_acquired

      def generate_payload(event) do
        data = %{
          network_id: to_string(event.network_id),
          server_ip: event.server_ip,
          password: event.password
        }

        {:ok, data}
      end

      @doc """
      It is always sent to the Account channel, so we don't need to filter data
      to unwanted listeners, like is the case for Server-channel events.
      """
      def whom_to_publish(event),
        do: %{account: event.entity_id}
    end

    trigger Notificable do

      use Helix.Event.Trigger.Notificable.Macros

      @class :account
      @code :server_password_acquired

      def whom_to_notify(event) do
        event.entity_id
      end
    end

    trigger Listenable do

      @doc false
      def get_objects(event),
        do: [event.server_id]
    end
  end
end
