defmodule Helix.Account.Repo.Migrations.AddDocumentsSupport do
  use Ecto.Migration

  alias Helix.Account.Model.Document.Enum, as: DocumentEnum

  def change do
    create table(:documents, primary_key: false) do
      add :document_id, DocumentEnum.type(), primary_key: true
      add :revision_id, :integer, primary_key: true

      add :current, :boolean, default: false, null: false

      add :content_raw, :text, null: false
      add :content_html, :text, null: false
      add :diff_raw, :text, null: false
      add :diff_html, :text, null: false
      add :update_reason, :text, null: false

      add :publish_date, :utc_datetime, null: false
      add :enforced_from, :utc_datetime, null: false
      add :enforced_until, :utc_datetime, default: nil
    end
    # No index needed because this is a very small table and indices would be
    # ignored anyway.

    create table(:document_signatures, primary_key: false) do
      add :account_id,
        references(:accounts, column: :account_id, type: :inet),
        primary_key: true
      add :document_id, DocumentEnum.type(), primary_key: true
      add :revision_id, :integer, primary_key: true

      add :signature_date, :utc_datetime, null: false
      add :ip_address, :inet, null: false
      add :user_agent, :text, null: false
    end
    create index(
      :document_signatures, [:document_id, :revision_id, :signature_date]
    )

    alter table(:accounts, primary_key: false) do
      add :tos_revision, :integer, null: false
      add :pp_revision, :integer, null: false
    end
  end
end
