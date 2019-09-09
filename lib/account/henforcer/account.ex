defmodule Helix.Account.Henforcer.Account do

  import Helix.Henforcer

  alias Helix.Account.Model.Account
  alias Helix.Account.Query.Account, as: AccountQuery

  @type account_exists_relay :: %{account: Account.t}
  @type account_exists_relay_partial :: %{}
  @type account_exists_error ::
    {false, {:account, :not_exists}, account_exists_relay_partial}

  @spec account_exists?(Account.id) ::
    {true, account_exists_relay}
    | account_exists_error
  def account_exists?(account_id) do
    with account = %Account{} <- AccountQuery.fetch(account_id) do
      reply_ok(%{account: account})
    else
      _ ->
        reply_error({:account, :not_exists})
    end
  end

  @type username_exists_relay :: %{account: Account.t}
  @type username_exists_relay_partial :: %{}
  @type username_exists_error ::
    {false, {:username, :not_exists}, username_exists_relay_partial}

  @spec username_exists?(Account.username) ::
    {true, username_exists_relay}
    | username_exists_error
  def username_exists?(username) do
    with account = %Account{} <- AccountQuery.fetch_by_username(username) do
      reply_ok(%{account: account})
    else
      _ ->
        reply_error({:username, :not_exists})
    end
  end

  @type email_exists_relay :: %{account: Account.t}
  @type email_exists_relay_partial :: %{}
  @type email_exists_error ::
    {false, {:email, :not_exists}, email_exists_relay_partial}

  @spec email_exists?(Account.email) ::
    {true, email_exists_relay}
    | email_exists_error
  def email_exists?(email) do
    with account = %Account{} <- AccountQuery.fetch_by_email(email) do
      reply_ok(%{account: account})
    else
      _ ->
        reply_error({:email, :not_exists})
    end
  end

  @type password_valid_relay :: %{}
  @type password_valid_relay_partial :: %{}
  @type password_valid_error ::
    {false, {:password, :insecure}, password_valid_relay_partial}

  @spec password_valid?(Account.username, Account.password) ::
    {true, password_valid_relay}
    | password_valid_error
  def password_valid?(username, password) do
    if username == password do
      reply_error({:password, :insecure})
    else
      reply_ok()
    end
  end

  @type can_create_account_relay :: %{}
  @type can_create_account_relay_partial :: %{}
  @type can_create_account_error ::
    password_valid_error
    | {false, {:email, :taken}, can_create_account_relay_partial}
    | {false, {:username, :taken}, can_create_account_relay_partial}

  @spec can_create_account?(term, term, term) ::
    {true, can_create_account_relay}
    | can_create_account_error
  def can_create_account?(username, password, email) do
    with \
      {true, _} <- password_valid?(username, password),
      {true, _} <- henforce_not(email_exists?(email), {:email, :taken}),
      {true, _} <- henforce_not(username_exists?(username), {:username, :taken})
    do
      reply_ok()
    end
  end

  @type can_sign_document_relay :: account_exists_relay
  @type can_sign_document_relay_partial :: can_sign_document_relay | %{}
  @type can_sign_document_error ::
    account_exists_error
    | {false, {:signature, :stale_document}, can_sign_document_relay_partial}

  @spec can_sign_document?(Account.id, {Document.id, Document.revision_id}) ::
    {true, can_sign_document_relay}
    | can_sign_document_error
  def can_sign_document?(account_id, {document_id, revision_id}) do
    with \
      {true, r1} <- account_exists?(account_id),
      account = r1.account
    do
      current_revision_id = Account.get_signed_revision_id(account, document_id)
      if current_revision_id <= revision_id do
        reply_ok()
      else
        reply_error({:signature, :stale_document})
      end
      |> wrap_relay(r1)
    end
  end
end
