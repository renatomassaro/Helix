defmodule Helix.Event.Trigger.Publishable do

  import HELL.Macros.Docp

  alias Hevent.Trigger

  alias HELL.Utils
  alias Helix.Event
  alias Helix.Account.Model.Account
  alias Helix.Entity.Model.Entity
  alias Helix.Server.Model.Server
  alias Helix.Session.State.SSE.PubSub, as: SSEPubSub

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

    domains =
      event
      |> Trigger.get_data(:whom_to_publish, @trigger)
      |> channel_mapper()

    event_payload = get_event_payload(event)

    case get_event_payload(event) do
      {dispatch_type, payload} ->
        SSEPubSub.publish(domains, {dispatch_type, payload})

      :noreply ->
        :noop
    end
  end

  def get_event_payload(event) do
    try do
      case Trigger.get_data([event], :generate_payload, @trigger) do
        {:ok, data} ->
          payload = render_event_payload(event, data)
          {:static, payload}

        noreply ->
          noreply
      end
    rescue
      UndefinedFunctionError ->
        {:dynamic, event}
    end
  end

  def get_event_payload(event, session) do
    case Trigger.get_data([event, session], :generate_payload, @trigger) do
      {:ok, data} ->
        render_event_payload(event, data)

      noreply ->
        noreply
    end
  end

  defp render_event_payload(event, data) do
    %{
      data: data,
      event: Trigger.get_data(event, :event_name, @trigger),
      meta: Event.Meta.render(event)
    }
  end

  # def generate_event(event, socket) do
  #   case Trigger.get_data([event, socket], :generate_payload, @trigger) do
  #     {:ok, data} ->
  #       payload =
  #         %{
  #           data: data,
  #           event: Trigger.get_data(event, :event_name, @trigger),
  #           meta: Event.Meta.render(event)
  #         }

  #       {:ok, payload}

  #     noreply ->
  #       noreply
  #   end
  # end

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
        casted_account_id =
          with %Entity.ID{} <- account_id do
            Account.ID.cast!(to_string(account_id))
          end

        [{:account, casted_account_id} | acc]
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
