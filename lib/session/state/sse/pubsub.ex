defmodule Helix.Session.State.SSE.PubSub do

  use GenServer

  alias Helix.Event.Trigger.Publishable, as: PublishableTrigger
  alias Helix.Core.Node.Manager, as: NodeManager
  alias Helix.MQ
  alias Helix.Session.Action.SSE, as: SSEAction
  alias Helix.Session.Model.SSE
  alias Helix.Session.Query.Session, as: SessionQuery
  alias Helix.Session.State.Session.API, as: SessionStateAPI
  alias Helix.Session.State.SSE.API, as: SSEStateAPI

  @node_id NodeManager.get_node_name()

  @registry_name :sse_pubsub

  # Time to wait when sending global requests in a canary fashion
  @canary_interval 100

  # Time to wait before deleting the queued messages in the database
  @delete_interval 2_000

  @initial_state %{
    awaiting_deletion: [],
    rate_limit: %{
      online: %{timer: nil, queued: nil, interval: 10_000}
    }
  }

  # Public API

  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: @registry_name)

  def publish(:global, payload),
    do: Helix.MQ.multicast("sse_queue_global", payload)

  def publish(domains, {dispatch_type, event}) do
    message_id = SSE.Queue.generate_message_id()

    nodes =
      domains
      |> SessionQuery.get_domains_sessions()
      |> sort_by_node()

    cluster_queue_data =
      Enum.reduce(nodes, %{}, fn {node_id, sessions}, acc ->
        notifications =
          sessions
          |> Enum.reduce([], fn session_id, acc ->
            session = SessionStateAPI.fetch(session_id)

            payload =
              if dispatch_type == :static do
                event
              else
                PublishableTrigger.get_event_payload(event, session)
              end

            if payload == :noreply do
              acc
            else
              notification =
                %{
                  session_id: session_id,
                  message_id: SSE.Queue.generate_message_id(),
                  event: payload
                }

              [notification | acc]
            end
          end)

        node_queue_data =
          Enum.reduce(notifications, [], fn notification, acc ->
            [{notification.message_id, notification.session_id} | acc]
          end)

        unless Enum.empty?(notifications) do
          MQ.publish(node_id, "sse_queue", notifications)
        end

        Map.put(acc, node_id, node_queue_data)
      end)

    SSEAction.bulk_insert_in_queue(cluster_queue_data)
  end

  defp sort_by_node(domains_sessions) do
    Enum.reduce(domains_sessions, %{}, fn {node_id, session_id}, acc ->
      current = acc[node_id] || []
      Map.put(acc, node_id, [session_id | current])
    end)
  end

  defp on_sse_msg(raw),
    do: GenServer.cast(@registry_name, {:notification, :sse_queue, raw})
  defp on_global_sse_msg(raw),
    do: GenServer.cast(@registry_name, {:notification, :sse_queue_global, raw})

  # Callbacks

  def init(_) do
    MQ.subscribe("sse_queue", &on_sse_msg/1)
    MQ.subscribe("sse_queue_global", &on_global_sse_msg/1)

    start_deletion_loop()

    {:ok, @initial_state}
  end

  def handle_cast({:request_resync, session_id}, state) do
    IO.puts "Reqeust requsync"
    # TODO: Resync won't fix anything here, as the SSE channel is closed.
    # Simply remove any indicative that the SSE could be working.

    {:noreply, state}
  end

  def handle_cast({:notification, :sse_queue_global, notification}, state) do
    {action, new_state} =
      case notification.event do
        "_online" ->
          rate_limit(:online, state, notification)

        _ ->
          {:push, state}
      end

    with :push <- action do
      canary_push(notification)
    end

    {:noreply, new_state}
  end

  def handle_cast({:notification, :sse_queue, notifications}, state) do
    ids_sent =
      Enum.reduce(notifications, [], fn notification, acc ->
        spawn fn ->
          session_push(notification.session_id, notification)
        end

        [notification.message_id | acc]
      end)

    new_state =
      %{state|
        awaiting_deletion: List.flatten([ids_sent | state.awaiting_deletion])
       }

    {:noreply, new_state}
  end

  def handle_info(:delete_awaiting, state) do
    with false <- Enum.empty?(state.awaiting_deletion) do
      spawn fn ->
        delete_awaiting_messages(state.awaiting_deletion)
      end
    end

    start_deletion_loop()

    {:noreply, %{state| awaiting_deletion: []}}
  end

  def handle_info({:rate_limit_timeout, event}, state) do
    # Grab any messages that were queued while the timer was running
    queued = state.rate_limit[event].queued

    # Reset the rate_limit data to the initial state
    new_state =
      update_in(
        state, [:rate_limit, event], fn _ -> %{queued: nil, timer: nil} end
      )

    {_, new_state} =
      if queued do
        # If there are queued messages, now is the time to push them...
        canary_push(queued)

        # ...and start a new rate_limit timer
        rate_limit(event, new_state, queued)
      else
        # No messages were queued while the timer was running, nothing to do.
        {:skip, new_state}
      end

    {:noreply, new_state}
  end

  def terminate(_reason, state) do
    spawn fn ->
      delete_awaiting_messages(state.awaiting_deletion)
    end
  end

  defp start_deletion_loop,
    do: Process.send_after(self(), :delete_awaiting, @delete_interval)

  def delete_awaiting_messages(awaiting_messages),
    do: SSEAction.bulk_remove_from_queue(awaiting_messages)

  defp session_push(session_id, payload) do
    with \
      {:ok, sse_pid} <- SSEStateAPI.fetch_sse(session_id),
      true <- Process.alive?(sse_pid)
    do
      sse_send(sse_pid, payload)
    else
      _ ->
        GenServer.cast(@registry_name, {:request_resync, session_id})
    end
  end

  defp canary_push(payload) do
    # `spawn` required so we can safely sleep in another process
    spawn fn ->
      sse_state = SSEStateAPI.get_all(merge?: false)

      Enum.each(sse_state, fn {shard_id, shard_data} ->
        unless Enum.empty?(shard_data) do
          Enum.each(shard_data, fn {session_id, sse_pid} ->
            sse_send(sse_pid, payload)
          end)

          # Wait some time before publishing to the next shard
          :timer.sleep(@canary_interval)
        end
      end)
    end
  end

  defp sse_send(sse_pid, payload),
    do: send(sse_pid, {:event, payload})

  defp rate_limit(event, state, payload) do
    if is_nil(state.rate_limit[event].timer) do
      # No timer running, so we can push right now and start a new timer
      timer =
        Process.send_after(
          self(), {:rate_limit_timeout, event}, state.rate_limit[event].interval
        )

      new_state =
        update_in(state, [:rate_limit, event, :timer], fn _ -> timer end)

      {:push, new_state}
    else
      # There is a running timer, so we can't push the payload right now. We
      # store the payload on `queued`, so it can be emitted after `interval`.
      new_state =
        update_in(state, [:rate_limit, event, :queued], fn _ -> payload end)

      {:wait, new_state}
    end
  end
end
