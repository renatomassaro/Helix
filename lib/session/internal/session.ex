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
    session_id
    |> Session.Unsynced.Query.by_id()
    |> Session.Unsynced.Query.filter_expired()
    |> Repo.one()
  end

  def create(session_id, session_data) do
    Repo.transaction fn ->
      session_id
      |> Session.Unsynced.Query.by_id()
      |> Repo.delete_all()

      session_id
      |> Session.create_session(session_data)
      |> Enum.reduce(nil, fn changeset, acc ->
        case Repo.insert(changeset) do
          {:ok, session = %Session{}} ->
            session

          {:ok, _} ->
            acc

          {:error, cs} ->
            Repo.rollback(cs)
        end
      end)
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
end
