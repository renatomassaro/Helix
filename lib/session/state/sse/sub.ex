defmodule Helix.Session.State.SSE.Sub do

  use GenServer

  alias Helix.Session.Action.SSE, as: SSEAction
  alias Helix.Session.State.Session.API, as: SessionStateAPI
  alias Helix.Session.State.SSE.API, as: SSEStateAPI
  alias Helix.Session.Repo

  @node_id "todo"

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

  # Callbacks

  def init(_) do
    {:ok, _, _} = Repo.listen("sse_queue_all")
    {:ok, _, _} = Repo.listen("sse_queue_" <> @node_id)

    start_deletion_loop()

    {:ok, @initial_state}
  end

  def handle_cast({:request_resync, session_id}, state) do
    IO.puts "Reqeust requsync"

    {:noreply, state}
  end

  def handle_info({:notification, _, _, "sse_queue_all", raw}, state) do
    notification = parse_notification(raw)

    {action, new_state} =
      case notification.event do
        "_online" ->
          # Limit once every 10s
          rate_limit(:online, state, notification)

        _ ->
          {:push, state}
      end

    with :push <- action do
      canary_push(notification)
    end

    {:noreply, new_state}
  end

  def handle_info({:notification, _, _, _channel_name, raw}, state) do
    notifications = parse_notification(raw)

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

  defp parse_notification(payload) do
    payload
    |> Poison.decode(keys: :atoms)
    |> elem(1)
  end
end
