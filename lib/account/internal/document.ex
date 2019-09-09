defmodule Helix.Account.Internal.Document do

  alias Helix.Account.Model.Account
  alias Helix.Account.Model.Document
  alias Helix.Account.Repo

  @spec fetch(Document.id, Document.revision_id) ::
    Document.t
    | nil
  def fetch(document_id, revision_id) do
    document_id
    |> Document.Query.by_pk(revision_id)
    |> Repo.one()
  end

  @spec fetch_current(Document.id) ::
    Document.t
    | no_return
  def fetch_current(document_id) do
    document_id
    |> Document.Query.by_current()
    |> Repo.one!()
  end

  @doc """
  Fetches the corresponding signature entry from `account_id` for
  {`document_id`, `revision_id`}. Returning `nil` means the user never signed
  this specific revision of the document.
  """
  def fetch_signature(account_id, document_id, revision_id) do
    account_id
    |> Document.Signature.Query.by_pk(document_id, revision_id)
    |> Repo.one()
  end

  @doc """
  Returns the current revision of `document_id` that is valid for `account_id`.
  """
  def fetch_current_signature(account_id, document_id) do
    account_id
    |> Document.Signature.Query.by_document(document_id)
    |> Document.Signature.Order.by_most_recent_signature()
    |> Document.Signature.Query.only(1)
    |> Repo.one()
  end

  @spec sign(Account.t, Document.t, Document.Signature.info) ::
    {:ok, Document.Signature.t}
    | {:error, Document.Signature.changeset}
  def sign(account = %Account{}, document = %Document{}, info) do
    %{
      account_id: account.account_id,
      document_id: document.document_id,
      revision_id: document.revision_id,
      ip_address: info.ip_address,
      user_agent: info.user_agent
    }
    |> Document.Signature.create_changeset()
    |> Repo.insert(on_conflict: :nothing)
  end
end
