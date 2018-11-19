defmodule Helix.Session.Repo.Migrations.InitialSetup do
  use Ecto.Migration

  def change do

    create table(:sessions, primary_key: false) do
      add :session_id, :uuid, primary_key: true
      add :account_id, :inet, null: false

      add :socket_data, :jsonb, null: false
      add :account_data, :jsonb, null: false

      add :expiration_date, :utc_datetime, null: false
    end
    create index(:sessions, [:account_id])
    create unique_index(:sessions, [:session_id, :account_id, :expiration_date])

    create table(:sessions_servers, primary_key: false) do
      add :session_id,
        references(
          :sessions, column: :session_id, type: :uuid, on_delete: :delete_all
        ),
        primary_key: true

      add :server_id, :inet, primary_key: true

      add :server_data, :jsonb, null: false
    end
    create index(:sessions_servers, [:server_id])

    create table(:sessions_unsynced, primary_key: false) do
      add :session_id, :uuid, primary_key: true
      add :account_id, :inet, null: false
      add :expiration_date, :utc_datetime, null: false
    end

    create table(:sessions_sse, primary_key: false) do
      add :session_id,
        references(
          :sessions, column: :session_id, type: :uuid, on_delete: :delete_all
        ),
        primary_key: true
      add :node_id, :string, null: false
    end
    create index(:sessions_sse, [:node_id])

    create table(:sse_queue, primary_key: false) do
      add :message_id, :smallint, primary_key: true
      add :session_id,
        references(
          :sessions, column: :session_id, type: :uuid, on_delete: :delete_all
        )

      add :node_id, :string, null: false
      add :creation_date, :utc_datetime, null: false
    end
  end
end
