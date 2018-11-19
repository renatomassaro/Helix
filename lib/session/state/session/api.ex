defmodule Helix.Session.State.Session.API do

  import HELL.Macros

  alias Helix.Server.Model.Server
  alias Helix.Session.Model.Session
  alias Helix.Session.Query.Session, as: SessionQuery
  alias Helix.Session.State.Session, as: SessionState

  def fetch(session_id) do
    case get(session_id) do
      {:ok, session, _} ->
        session

      {:error, _} ->
        nil
    end
  end

  defdelegate get(session_id),
    to: SessionState

  defdelegate get_server(session_id, server_id),
    to: SessionState

  defdelegate save(session_id, session),
    to: SessionState

  defdelegate delete(session_id),
    to: SessionState

  def check_permission(id_tuple, synced?: synced?) do
    with \
      {:error, _} <- retrieve_cache(id_tuple, synced?: synced?),
      found = {:ok, session, context} <- retrieve_db(id_tuple, synced?: synced?)
    do
      IO.puts "from db"
      found
    else
      cache_hit = {:ok, session, context} ->
        IO.puts "From cache"
        cache_hit

      error = {:error, reason} ->
        error
    end
  end

  defp retrieve_cache({session_id}, synced?: true),
    do: SessionState.get(session_id)
  defp retrieve_cache({session_id, server_id = %Server.ID{}}, synced?: true),
    do: SessionState.get_server(session_id, server_id)
  defp retrieve_cache({session_id}, synced?: false),
    do: {:error, :nxsession}

  defp retrieve_db({session_id}, synced?: true) do
    case SessionQuery.fetch(session_id) do
      session = %{} ->
        cache_result(session, session_id)

        {:ok, session, %{}}

      nil ->
        {:error, :nxsession}
    end
  end

  defp retrieve_db({session_id, server_id}, synced?: true) do
    case SessionQuery.fetch_server(session_id, server_id) do
      result = {:ok, session = %{}, %{}} ->
        cache_result(session, session_id)

        result

      nil ->
        {:error, :nxauth}
    end
  end

  defp retrieve_db({session_id}, synced?: false) do
    case SessionQuery.fetch_unsynced(session_id) do
      session = %{} ->
        {:ok, %{}, session}

      nil ->
        # The given session isn't on the `unsynced` list. That does not mean it
        # is invalid! It may already be synced, in which case the client is
        # performing a resync, relogin or login-after-lock request. If *that*
        # fails, then it's an invalid session.
        case check_permission({session_id}, synced?: true) do
          {:ok, session, _} ->
            # The SyncRequest expects a custom context.
            {:ok, session, %{resync: true}}

          nil ->
            nil
        end
    end
  end

  defp cache_result(session, session_id) do
    hespawn fn ->
      SessionState.save(session_id, session)
    end
  end
end
