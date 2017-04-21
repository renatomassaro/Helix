defmodule Helix.Hardware.Repo do
  use Ecto.Repo, otp_app: :helix
  alias HELL.EctoHelpers

  def set_schema(conn, schema) do
    EctoHelpers.set_schema(conn, schema, __MODULE__)
  end
end
