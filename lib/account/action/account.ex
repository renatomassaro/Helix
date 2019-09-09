defmodule Helix.Account.Action.Account do

  alias Helix.Account.Action.Session, as: SessionAction
  alias Helix.Account.Internal.Account, as: AccountInternal
  alias Helix.Account.Model.Account
  alias Helix.Account.Model.AccountSession
  alias Helix.Account.Model.Document

  alias Helix.Account.Event.Account.Created, as: AccountCreatedEvent
  alias Helix.Account.Event.Account.Verified, as: AccountVerifiedEvent

  @spec create(Account.email, Account.username, Account.password) ::
    {:ok, Account.t, events :: list}
    | {:error, Ecto.Changeset.t}
  @doc """
  Creates an user

  ## Examples

      iex> create("foo@bar.com", "not_an_admin", "password_rhymes_with_assword")
      {:ok, %Account{}}

      iex> create("invalid email", "I^^^nvalid U**ser", "badpas")
      {:error, %Ecto.Changeset{}}
  """
  def create(email, username, password) do
    params = %{
      email: email,
      username: username,
      password: password
    }

    case AccountInternal.create(params) do
      {:ok, account} ->
        {:ok, account, [AccountCreatedEvent.new(account)]}

      error ->
        error
    end
  end

  @spec login(Account.username, Account.password) ::
    {:ok, Account.t, AccountSession.token}
    | {:error, :notfound}
    | {:error, :internalerror}
  @doc """
  Checks if `password` logs into `username`'s account

  This function is safe against timing attacks
  """
  def login(username, password) do
    # TODO: check account status (when implemented) and return error for
    #   non-confirmed email and for banned account
    with \
      account = %{} <- AccountInternal.fetch_by_username(username) || :nxacc,
      true <- Account.check_password(account, password) || :badpass,
      # {:ok, token} <- SessionAction.generate_token(account)
      token = "todorandomtoken"
    do
      {:ok, account, token}
    else
      :nxacc ->
        {:error, :notfound}
      :badpass ->
        {:error, :notfound}
      _ ->
        {:error, :internalerror}
    end
  end

  def verify(email_verification = %{account: account}) do
    case AccountInternal.verify(account, email_verification) do
      {:ok, new_account} ->
        {:ok, new_account, [AccountVerifiedEvent.new(new_account)]}

      {:error, _} ->
        {:error, :internal}
    end
  end


  @spec sign_document(Account.t, Document.t, Document.Signature.info) ::
    {:ok, Account.t}
    | {:error, :internal}
  def sign_document(account = %Account{}, document = %Document{}, info) do
    case AccountInternal.sign_document(account, document, info) do
      {:ok, new_account} ->
        {:ok, new_account, []}

      {:error, _} ->
        {:error, :internal}
    end
  end
end
