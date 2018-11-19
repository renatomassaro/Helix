defmodule Helix.Session.Internal.Session do

  alias Helix.Account.Model.Account
  alias Helix.Session.Model.Session
  alias Helix.Session.Repo

  def fetch(session_id) do
    session_id
    |> Session.Query.by_id()
    |> Session.Query.filter_expired()
    |> Session.Query.join_servers()
    |> Repo.one()
    |> Session.format()
  end

  def fetch_server(session_id, server_id) do
    with \
      session = %{} <- fetch(session_id),
      context = %{} <- session.servers[to_string(server_id)]
    do
      {:ok, session, Map.put(context, :server_id, server_id)}
    else
      _ ->
        nil
    end
  end

  def fetch_unsynced(session_id) do
    unsynced_session =
      session_id
      |> Session.Unsynced.Query.by_id()
      |> Session.Unsynced.Query.filter_expired()
      |> Repo.one()

    with %{} <- unsynced_session do
      Map.from_struct(unsynced_session)
    end
  end

  def is_sse_active?(session_id) do
    session_sse =
      session_id
      |> Session.SSE.Query.by_id()
      |> Repo.one()

    with %Session.SSE{} <- session_sse || false do
      true
    end
  end

  def get_account_domain(accounts) do
    accounts
    |> Session.SSE.Query.get_account_domain()
    |> Repo.all()
  end

  def get_server_domain(servers) do
    servers
    |> Session.SSE.Query.get_server_domain()
    |> Repo.all()
  end

  def create(session_id, session_data) do
    Repo.transaction fn ->
      # Remove temporary, unsynced session
      session_id
      |> Session.Unsynced.Query.by_id()
      |> Repo.delete_all()

      %{
        session: session_changeset,
        servers: servers_changeset
      } = Session.create_session(session_id, session_data)

      conflict_opts_session =
        [on_conflict: :replace_all, conflict_target: [:session_id]]
      conflict_opts_server =
        [on_conflict: :replace_all, conflict_target: [:session_id, :server_id]]

      case Repo.insert(session_changeset, conflict_opts_session) do
        {:ok, session} ->
          Enum.each(servers_changeset, fn server_changeset ->
            Repo.insert!(server_changeset, conflict_opts_server)
          end)

          session

        _ ->
          Repo.rollback(:error)
      end
    end
  end

  def create_unsynced(account_id = %Account.ID{}) do
    %{
      account_id: account_id,
      session_id: Session.generate_session_id()
    }
    |> Session.Unsynced.create_changeset()
    |> Repo.insert()
  end

  def delete(session_id) do
    session_id
    |> Session.Query.by_id()
    |> Repo.delete_all()
  end

  def link_sse(session_id, node_id) do
    %{
      session_id: session_id,
      node_id: node_id
    }
    |> Session.SSE.create_changeset()
    |> Repo.insert()
  end

  def unlink_sse(session_id) do
    session_id
    |> Session.SSE.Query.by_id()
    |> Repo.delete_all()

    :ok
  end
end
