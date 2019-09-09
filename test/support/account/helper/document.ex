defmodule Helix.Test.Account.Helper.Document do

  alias Helix.Account.Seeds, as: AccountSeeds
  alias Helix.Account.Model.Document
  alias Helix.Account.Query.Document, as: DocumentQuery
  alias Helix.Account.Repo, as: AccountRepo

  def reset_db do
    AccountRepo.delete_all(Document)
    AccountRepo.delete_all(Document.Signature)
    AccountSeeds.document_seed()
  end

  def get_current do
    random_document()
    |> get_current()
  end

  def get_current(document_id),
    do: DocumentQuery.fetch_current(document_id)

  def random_document,
    do: Enum.random([:tos, :pp])
end
