defmodule Helix.Webserver.Plugs.Entrypoint do

  import Plug.Conn

  alias Helix.Webserver.Session, as: SessionWeb

  def init(opts),
    do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("content-type", "application/json; charset=utf-8")
    |> fetch_cookies()
    |> SessionWeb.fetch_session()
  end
end
