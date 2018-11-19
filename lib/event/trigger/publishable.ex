defmodule Helix.Event.Trigger.Publishable do

  import HELL.Macros.Docp

  alias Hevent.Trigger

  alias HELL.Utils
  alias Helix.Event
  alias Helix.Account.Model.Account
  alias Helix.Entity.Model.Entity
  alias Helix.Server.Model.Server
  alias Helix.Session.State.SSE.Pub, as: SSEPub

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

    {:ok, event_payload} = generate_event(event, %{})

    event
    |> Trigger.get_data(:whom_to_publish, @trigger)
    |> channel_mapper()
    |> SSEPub.publish(event_payload)
  end

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

  defp channel_mapper(whom_to_publish, acc \\ [])
  defp channel_mapper(:everyone, _),
    do: :global

  defp channel_mapper(publish = %{server: servers}, acc) do
    acc =
      servers
      |> Utils.ensure_list()
      |> Enum.uniq()
      |> Enum.reduce(acc, fn server_id, acc ->
        [{:server, server_id} | acc]
      end)

    channel_mapper(Map.delete(publish, :server), acc)
  end

  defp channel_mapper(publish = %{account: accounts}, acc) do
    acc =
      accounts
      |> Utils.ensure_list()
      |> Enum.uniq()
      |> Enum.reduce(acc, fn account_id, acc ->
        [{:account, account_id} | acc]
      end)

    channel_mapper(Map.delete(publish, :account), acc)
  end

  defp channel_mapper(empty_map = %{}, acc) when map_size(empty_map) == 0,
    do: acc

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
