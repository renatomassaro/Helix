defmodule Helix.Process.Repo.Migrations.TOPRewrite do
  use Ecto.Migration

  def change do

    drop table(:process_servers)
    drop table(:processes)

    create table(:processes, primary_key: false) do
      add :process_id, :inet, primary_key: true

      # Identifiers
      add :gateway_id, :inet, null: false
      add :target_id, :inet, null: false
      add :source_entity_id, :inet, null: false
      add :network_id, :inet

      # Custom keys
      add :connection_id, :inet  # Renamed to `src_connection_id`
      # add :tgt_connection_id, :inet

      add :file_id, :inet  # Renamed to `src_file_id`
      # add :tgt_connection_id, :inet
      # add :bounce_id, :inet (no index)

      # Helix.Process stuff
      add :data, :jsonb, null: false
      add :type, :string, null: false
      add :priority, :integer, null: false

      # Resources
      add :objective, :jsonb, null: false
      add :processed, :jsonb

      add :l_reserved, :jsonb
      add :r_reserved, :jsonb

      add :l_limit, :jsonb
      add :r_limit, :jsonb

      add :l_dynamic, {:array, :string}, null: false
      add :r_dynamic, {:array, :string}

      add :static, :jsonb, null: false
      add :last_checkpoint_time, :utc_datetime_usec

      # Metadata
      add :creation_time, :utc_datetime_usec, null: false
    end
    # Used to identify all processes of #{type} on #{server}
    # Also used when fetching all processes on #{server}
    create index(:processes, [:gateway_id, :type])

    # Useful but currently unused. Uncomment me if you need me (no one does)
    # create index(:processes, [:target_id])

    # Used on e.g. FileDelete operations, where the underlying process should be
    # killed if the file was modified.
    create index(:processes, [:file_id])  # Changed to partial

    # Used on e.g. ConnectionClosed operations, where the underlying process
    # should be killed if the connection was terminated
    create index(:processes, [:connection_id])  # Changed to partial

    # create index(:processes, [:tgt_file_id]) (partial)
    # create index(:processes, [:tgt_connection_id]) (partial)
  end
end
