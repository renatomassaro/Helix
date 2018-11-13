defmodule Helix.Log.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :helix,
    adapter: Ecto.Adapters.Postgres
end
