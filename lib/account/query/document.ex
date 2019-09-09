defmodule Helix.Account.Query.Document do

  alias Helix.Account.Internal.Document, as: DocumentInternal
  alias Helix.Account.Model.Document

  defdelegate fetch(document_id, revision_id),
    to: DocumentInternal

  defdelegate fetch_current(document_id),
    to: DocumentInternal

  @doc """
  Fetches the corresponding signature entry from `account_id` for
  {`document_id`, `revision_id`}. Returning `nil` means the user never signed
  this specific revision of `document_id`.
  """
  defdelegate fetch_signature(account_id, document_id, revision_id),
    to: DocumentInternal

  @doc """
  Returns the current revision of `document_id` that is valid for `account_id`.
  Returning `nil` means the user never signed ANY revision of `document_id`.
  """
  defdelegate fetch_current_signature(account_id, document_id),
    to: DocumentInternal
end
