defmodule Helix.Account.Internal.Account do

  alias Helix.Account.Internal.Email, as: EmailInternal
  alias Helix.Account.Internal.Document, as: DocumentInternal
  alias Helix.Account.Model.Account
  alias Helix.Account.Model.AccountSetting
  alias Helix.Account.Model.Document
  alias Helix.Account.Model.Setting
  alias Helix.Account.Repo

  @spec fetch(Account.id) ::
    Account.t
    | nil
  def fetch(id),
    do: Repo.get(Account, id)

  @spec fetch_by_email(Account.email) ::
    Account.t
    | nil
  def fetch_by_email(email) do
    String.downcase(email)
    |> Account.Query.by_email()
    |> Repo.one()
  end

  @spec fetch_by_username(Account.username) ::
    Account.t
    | nil
  def fetch_by_username(username) do
    String.downcase(username)
    |> Account.Query.by_username()
    |> Repo.one()
  end

  @spec get_settings(Account.t) ::
    Setting.t
  def get_settings(account) do
    settings =
      account
      |> AccountSetting.Query.by_account()
      |> AccountSetting.Query.select_settings()
      |> Repo.one()

    settings || %Setting{}
  end

  @spec create(Account.creation_params) ::
    {:ok, Account.t}
    | {:error, Account.changeset}
  def create(params) do
    Repo.transaction(fn ->
      account_changeset = Account.create_changeset(params)

      with \
        {:ok, account} <- Repo.insert(account_changeset),
        {:ok, email_verification} <- EmailInternal.create_verification(account)
      do
        account
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @spec update(Account.t, Account.update_params) ::
    {:ok, Account.t}
    | {:error, Account.changeset}
  def update(account, params) do
    account
    |> Account.update_changeset(params)
    |> Repo.update()
  end

  # @spec delete(Account.t) ::
  #   :ok
  # def delete(account) do
  #   Repo.delete(account)

  #   :ok
  # end

  @spec verify(Account.t, Email.Verification.t) ::
    {:ok, Account.t}
    | {:error, Account.changeset | Email.Verification.changeset}
  def verify(account, email_verification) do
    Repo.transaction(fn ->
      with \
        account_changeset = Account.mark_as_verified(account),
        {:ok, account} <- Repo.update(account_changeset),
        :ok <- EmailInternal.remove_entries(account.account_id)
      do
        account
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @spec sign_document(Account.t, Document.t, Document.Signature.info) ::
    {:ok, Account.t}
    | {:error, Account.changeset | Document.Signature.changeset}
  def sign_document(account = %Account{}, document = %Document{}, info) do
    Repo.transaction(fn ->
      with \
        account_changeset = Account.mark_as_signed(account, document),
        {:ok, account} <- Repo.update(account_changeset),
        {:ok, _} <- DocumentInternal.sign(account, document, info)
      do
        account
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @spec put_settings(Account.t, map) ::
    {:ok, Setting.t}
    | {:error, reason :: term}
  def put_settings(account, settings) do
    id = account.account_id
    account_settings = Repo.get(AccountSetting, id) || %AccountSetting{}
    params = %{account_id: account.account_id, settings: settings}

    changeset = AccountSetting.changeset(account_settings, params)

    case Repo.insert_or_update(changeset) do
      {:ok, %{settings: settings}} ->
        {:ok, settings}
      error = {:error, _} ->
        error
    end
  end
end
