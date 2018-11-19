defmodule Helix.Session.Internal.SSE do

  alias Helix.Session.Model.SSE, as: SSE
  alias Helix.Session.Repo

  def bulk_insert_in_queue(cluster_sent_messages) do
    now = DateTime.truncate(DateTime.utc_now(), :second)

    cluster_entries =
      cluster_sent_messages
      |> Enum.reduce([], fn {node_id, messages}, acc ->
        node_entries =
          Enum.reduce(messages, [], fn {message_id, session_id}, acc ->
            entry =
              %{
                message_id: message_id,
                session_id: session_id,
                node_id: node_id,
                creation_date: now
              }

            [entry | acc]
          end)

        [node_entries | acc]
      end)
      |> List.flatten()

    Repo.insert_all(SSE.Queue, cluster_entries)
  end

  def bulk_remove_from_queue(message_id_list) do
    message_id_list
    |> SSE.Queue.Query.in_id()
    |> Repo.delete_all()
  end
end
