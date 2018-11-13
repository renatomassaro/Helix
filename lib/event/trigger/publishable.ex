defmodule Helix.Event.Trigger.Publishable do

  import HELL.Macros.Docp

  alias Hevent.Trigger

  alias HELL.Utils
  alias Helix.Event
  alias Helix.Account.Model.Account
  alias Helix.Entity.Model.Entity
  alias Helix.Server.Model.Server
  alias Helix.Server.State.Websocket.Channel, as: ServerWebsocketChannelState

  @type whom_to_publish ::
    %{
      optional(:server) => [Server.id],
      optional(:account) => [Account.id]
    }

  @type channel_account_id :: Account.id | Entity.id

  @trigger Publishable

  # Entrypoint for Hevent's trigger handler
  def flow(event) do
    event = add_event_identifier(event)

    event
    |> Trigger.get_data(:whom_to_publish, @trigger)
    |> channel_mapper()
    # |> Enum.each(&(Helix.Webserver.Endpoint.broadcast(&1, "event", event)))
  end

  # Entrypoint for socket's `handle_event`
  def generate_event(event, socket) do
    case Trigger.get_data([event, socket], :generate_payload, @trigger) do
      {:ok, data} ->
        payload =
          %{
            data: data,
            event: Trigger.get_data(event, :event_name, @trigger),
            meta: Event.Meta.render(event)
          }

        {:ok, payload}

      noreply ->
        noreply
    end
  end

  docp """
  Interprets the return `Publishable.whom_to_publish/1` format, returning a list
  of valid channel topics/names.
  """
  @spec channel_mapper(whom_to_publish) ::
    channels :: [String.t]
  defp channel_mapper(whom_to_publish, acc \\ [])
  defp channel_mapper(publish = %{server: servers}, acc) do
    acc =
      servers
      |> Utils.ensure_list()
      |> Enum.uniq()
      |> get_server_channels()
      |> List.flatten()
      |> Kernel.++(acc)

    channel_mapper(Map.delete(publish, :server), acc)
  end

  defp channel_mapper(publish = %{account: accounts}, acc) do
    acc =
      accounts
      |> Utils.ensure_list()
      |> Enum.uniq()
      |> get_account_channels()
      |> List.flatten()
      |> Kernel.++(acc)

    channel_mapper(Map.delete(publish, :account), acc)
  end

  defp channel_mapper(%{}, acc),
    do: acc

  @spec get_server_channels([Server.id] | Server.id) ::
    channels :: [String.t]
  defp get_server_channels(servers) when is_list(servers),
    do: Enum.map(servers, &get_server_channels/1)
  defp get_server_channels(server_id) do
    open_channels = ServerWebsocketChannelState.list_open_channels(server_id)

    # Returns remote channels (joined using nips)
    nips =
      if open_channels do
        Enum.map(open_channels, fn channel ->
          "server:"
          |> concat(channel.network_id)
          |> concat("@")
          |> concat(channel.ip)
          |> concat("#")
          |> concat(channel.counter)
        end)
      else
        []
      end

    # Also include the server ID as channel (used on local (gateway) join)
    nips ++ ["server:" <> to_string(server_id)]
  end

  @spec get_account_channels([channel_account_id] | channel_account_id) ::
    channels :: [String.t]
  defp get_account_channels(accounts) when is_list(accounts),
    do: Enum.map(accounts, &get_account_channels/1)
  defp get_account_channels(account_id),
    do: ["account:" <> to_string(account_id)]

  defp concat(a, b),
    do: a <> to_string(b)

  @spec add_event_identifier(Event.t) ::
    Event.t
  docp """
  Adds the event unique identifier.

  Keep in mind that this unique identifier is for the *event*, i.e. the fact
  that something happened. If this event gets broadcasted to multiple players,
  each one of them will share the same event identifier.
  """
  defp add_event_identifier(event),
    do: Event.set_event_id(event, Event.generate_id())
end
