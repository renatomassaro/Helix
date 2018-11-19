defmodule Helix.Session.State.SSE.Pub do

  alias Helix.Session.Action.SSE, as: SSEAction
  alias Helix.Session.Model.SSE
  alias Helix.Session.Query.Session, as: SessionQuery
  alias Helix.Session.Repo

  @node_id "todo"

  def publish(:global, payload),
    do: pg_notify("sse_queue_all", payload)

  def publish(domains, event) do
    message_id = SSE.Queue.generate_message_id()

    nodes =
      domains
      |> SessionQuery.get_domains_sessions()
      |> sort_by_node()
      |> IO.inspect()

    IO.inspect(nodes)

    cluster_queue_data =
      Enum.reduce(nodes, %{}, fn {node_id, sessions}, acc ->
        notifications =
          Enum.map(sessions, fn session_id ->
            %{
              session_id: session_id,
              message_id: SSE.Queue.generate_message_id(),
              event: event
            }
          end)

        node_queue_data =
          Enum.reduce(notifications, [], fn notification, acc ->
            [{notification.message_id, notification.session_id} | acc]
          end)

        pg_notify("sse_queue_" <> node_id, notifications)
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

  defp pg_notify(channel, notification) do
    notification_str = Poison.encode!(notification)
    Ecto.Adapters.SQL.query(
      Repo, "NOTIFY \"#{channel}\", '#{notification_str}'"
    )
  end
end
