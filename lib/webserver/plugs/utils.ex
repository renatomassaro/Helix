defmodule Helix.Webserver.Plugs.Utils do

  import Plug.Conn

  def json_body(data),
    do: Phoenix.json_library().encode_to_iodata!(data)

  def halt_error(conn, reason, status \\ 403) do
    conn
    |> resp(status, json_body(%{error: %{reason: reason}}))
    |> halt()
  end
end
