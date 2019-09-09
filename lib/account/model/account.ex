defmodule Helix.Account.Model.Account do

  use Ecto.Schema
  use HELL.ID, field: :account_id

  import Ecto.Changeset
  import HELL.Ecto.Macros
  import HELL.Macros

  alias Comeonin.Bcrypt
  alias Ecto.Changeset
  alias Helix.Entity.Model.Entity
  alias Helix.Account.Model.Document

  @type email :: String.t
  @type username :: String.t
  @type password :: String.t
  @type t :: %__MODULE__{
    account_id: id,
    email: email,
    username: username,
    display_name: String.t,
    password: password,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @type creation_params :: %{
    email: email,
    username: username,
    password: password
  }
  @type update_params :: %{
    optional(:email) => email,
    optional(:password) => password,
    optional(:verified) => boolean
  }

  @type changeset :: %Ecto.Changeset{data: %__MODULE__{}}

  @creation_fields [:email, :username, :password]
  @update_fields [:email, :password, :verified, :tos_revision, :pp_revision]

  @derive {Poison.Encoder, only: [:email, :username, :account_id]}
  schema "accounts" do
    field :account_id, id(),
      primary_key: true

    field :email, :string
    field :username, :string
    field :display_name, :string
    field :password, :string

    field :verified, :boolean,
      default: false
    field :tos_revision, :integer,
      default: 0
    field :pp_revision, :integer,
      default: 0

    timestamps()
  end

  @spec create_changeset(creation_params) ::
    changeset
  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> generic_validations()
    |> prepare_changes()
    |> put_pk(%{}, :account)
  end

  @spec update_changeset(t | changeset, update_params) ::
    changeset
  def update_changeset(schema, params) do
    schema
    |> cast(params, @update_fields)
    |> generic_validations()
    |> prepare_changes()
  end

  @spec mark_as_verified(t | changeset) ::
    changeset
  def mark_as_verified(account) do
    account
    |> update_changeset(%{verified: true})
  end

  @spec mark_as_signed(t, Document.t) ::
    changeset
  def mark_as_signed(account, document) do
    current_signed_revision = get_signed_revision_id(account, document)
    field = get_document_field(document)
    changeset = change(account)

    if current_signed_revision > document.revision_id do
      add_error(changeset, field, "signing_stale_document")
    else
      update_changeset(changeset, %{field => document.revision_id})
    end
  end

  def get_signed_revision_id(account, %{document_id: document_id}),
    do: get_signed_revision_id(account, document_id)
  def get_signed_revision_id(account, document_id) when is_atom(document_id) do
    field = get_document_field(document_id)

    Map.fetch!(account, field)
  end

  defp get_document_field(%{document_id: document_id}),
    do: get_document_field(document_id)
  defp get_document_field(:tos),
    do: :tos_revision
  defp get_document_field(:pp),
    do: :pp_revision

  @spec check_password(t, password) ::
    boolean
  @doc """
  Checks if `pass` matches with `account`'s password

  This function is safe against timing attacks by always traversing the whole
  input string

  ## Examples

      iex> check_password(account, "correct password")
      true

      iex> check_password(account, "incorrect password")
      false
  """
  def check_password(account = %__MODULE__{}, pass),
    do: Bcrypt.checkpw(pass, account.password)

  @spec cast_from_entity(Entity.id) ::
    id
  @doc """
  "Translates" an Entity.id into Account.id
  """
  def cast_from_entity(entity_id = %Entity.ID{}),
    do: __MODULE__.ID.cast!(to_string(entity_id))

  @spec generic_validations(Changeset.t) ::
    Changeset.t
  defp generic_validations(changeset) do
    changeset
    |> validate_required([:email, :username, :password])
    |> validate_length(:password, min: 6)
    |> validate_change(:email, &validate_email/2)
    |> validate_change(:username, &validate_username/2)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end

  @spec prepare_changes(Changeset.t) ::
    Changeset.t
  defp prepare_changes(changeset) do
    changeset
    |> put_display_name()
    |> update_change(:email, &String.downcase/1)
    |> update_change(:username, &String.downcase/1)
    |> update_change(:password, &Bcrypt.hashpwsalt/1)
  end

  @spec put_display_name(Changeset.t) ::
    Changeset.t
  defp put_display_name(changeset) do
    case fetch_change(changeset, :username) do
      {:ok, username} ->
        put_change(changeset, :display_name, username)
      :error ->
        changeset
    end
  end

  @spec validate_email(:email, email) ::
    []
    | [email: String.t]
  docp """
  Validates that the email is a valid email address
  """
  defp validate_email(:email, value) do
    is_binary(value)
    # TODO: Remove this regex and use something better
    && Regex.match?(~r/^[\w0-9\.\-\_\+]+@[\w0-9\.\-\_]+\.[\w0-9\-]+$/ui, value)
    && []
    || [email: "has invalid format"]
  end

  @spec validate_username(:username, username) ::
    []
    | [username: String.t]
  docp """
  Validates that the username contains just alphanumeric and `!?$%-_.`
  characters.
  """
  defp validate_username(:username, value) do
    is_binary(value)
    && Regex.match?(~r/^[a-zA-Z0-9][a-zA-Z0-9\!\?\$\%\-\_\.]{1,15}$/, value)
    && []
    || [username: "has invalid format"]
  end

  query do

    alias Helix.Account.Model.Account

    @spec by_id(Queryable.t, Account.idtb) ::
      Queryable.t
    def by_id(query \\ Account, id),
      do: where(query, [a], a.account_id == ^id)

    @spec by_email(Queryable.t, Account.email) ::
      Queryable.t
    def by_email(query \\ Account, email) do
      email = String.downcase(email)

      where(query, [a], a.email == ^email)
    end

    @spec by_username(Queryable.t, Account.username) ::
      Queryable.t
    def by_username(query \\ Account, username) do
      username = String.downcase(username)

      where(query, [a], a.username == ^username)
    end
  end
end
