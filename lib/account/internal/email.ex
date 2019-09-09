defmodule Helix.Account.Internal.Email do

  alias Helix.Account.Model.Account
  alias Helix.Account.Model.Email
  alias Helix.Account.Repo

  @spec fetch_verification_by_key(Email.Verification.key) ::
    Email.Verification.t
    | nil
  def fetch_verification_by_key(key) do
    key
    |> Email.Verification.Query.by_key()
    |> Email.Verification.Query.join_account()
    |> Repo.one()
  end

  @spec create_verification(Account.t) ::
    {:ok, Email.Verification.t}
    | {:error, Email.Verification.changeset}
  def create_verification(account) do
    params = %{account_id: account.account_id}

    params
    |> Email.Verification.create_changeset()
    |> Repo.insert()
  end

  def remove_entries(account_id = %Account.ID{}) do
    account_id
    |> Email.Verification.Query.by_account_id()
    |> Repo.delete_all()

    :ok
  end
end
