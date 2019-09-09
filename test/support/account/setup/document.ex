defmodule Helix.Test.Account.Setup.Document do

  alias Ecto.Changeset

  alias HELL.DateUtils
  alias Helix.Account.Model.Document
  alias Helix.Account.Repo, as: AccountRepo

  def document(opts \\ []) do
    {document, related} = fake_document(opts)

    {:ok, inserted} = AccountRepo.insert(document)

    {inserted, related}
  end
  def document!(opts \\ []),
    do: document(opts) |> elem(0)

  def fake_document(opts) do
    document_id = opts[:id] || Enum.random([:tos, :pp])
    revision_id = opts[:rev_id] || 2

    current? = opts[:current?] || true
    enforced? = opts[:enforced?] || true

    content_map =
      %{
        content_raw: "nope",
        content_html: "<p>Nope</p>",
        diff_raw: "nope",
        diff_html: "<p>nope</p>",
        update_reason: "test"
      }

    enforced_from =
      if enforced? do
        DateUtils.utc_now(:second)
      else
        DateUtils.date_after(3600)
      end

    creation_params =
      %{
        document_id: document_id,
        revision_id: revision_id,
        enforced_from: enforced_from
      }
      |> Map.merge(content_map)

    changeset = Document.create_changeset(creation_params)

    changeset =
      if opts[:enforced_until] do
        Changeset.put_change(changeset, :enforced_until, opts[:enforced_until])
      else
        changeset
      end

    changeset =
      if opts[:current?] do
        Changeset.put_change(changeset, :current, true)
      else
        Changeset.put_change(changeset, :current, false)
      end

    document = Changeset.apply_changes(changeset)

    {document, %{changeset: changeset}}
  end
end
