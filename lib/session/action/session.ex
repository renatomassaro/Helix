defmodule Helix.Session.Action.Session do

  alias Helix.Account.Model.Account
  alias Helix.Session.Internal.Session, as: SessionInternal

  def create_unsynced(%Account{account_id: account_id}),
    do: create_unsynced(account_id)
  def create_unsynced(account_id = %Account.ID{}) do
    case SessionInternal.create_unsynced(account_id) do
      {:ok, unsynced_session} ->
        {:ok, unsynced_session}

      {:error, _changeset} ->
        {:error, :internal}
    end
  end

  def create(session_id, session_data) do
    case SessionInternal.create(session_id, session_data) do
      {:ok, session} ->
        {:ok, session}

      {:error, _changeset} ->
        {:error, :internal}
    end
  end
end
