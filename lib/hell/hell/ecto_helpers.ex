defmodule HELL.EctoHelpers do

  def set_schema(conn, schema, module) do
    database = Application.get_env(:helix, module)[:database]
    query = Postgrex.query!(conn, "select current_database()", [])
    [[ current_db ]] = query.rows
    if current_db == database do
      _ = Postgrex.query(conn, "CREATE SCHEMA AUTHORIZATION #{schema}", [])
      Postgrex.query!(conn, "SET search_path=#{schema}", [])
    end
  end
end
