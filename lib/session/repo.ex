defmodule Helix.Session.Repo do
  use Ecto.Repo,
    otp_app: :helix,
    adapter: Ecto.Adapters.Postgres

  def listen(channel_name) do
    with \
      {:ok, pid} <- Postgrex.Notifications.start_link(__MODULE__.config()),
      {:ok, ref} <- Postgrex.Notifications.listen(pid, channel_name)
    do
      {:ok, pid, ref}
    end
  end
end
