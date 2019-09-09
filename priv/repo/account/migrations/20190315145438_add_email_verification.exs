defmodule Helix.Account.Repo.Migrations.AddEmailVerification do
  use Ecto.Migration

  def change do

    create table(:email_verifications, primary_key: false) do
      add :key, :string, primary_key: true
      add :account_id,
        references(:accounts, column: :account_id, type: :inet),
        null: false

      add :creation_date, :utc_datetime, null: false
    end
    create index(:email_verifications, [:account_id])
    create index(:email_verifications, [:creation_date])
  end
end
