defmodule Helix.Webserver.HelixController do
  use Helix.Webserver, :controller

  import Plug.Conn

  @prefix ")]}'\n"

  def index(conn = %Plug.Conn{status: code}, _) when is_integer(code) do
    response =
      Phoenix.json_library().encode_to_iodata!(conn.assigns.helix_response)

    response =
      if response == "{}" do
        response
      else
        prepend_loop(response)
      end

    send_resp(conn, conn.status, response)
  end

  defp prepend_loop([first | rest]),
    do: [@prefix <> first | rest]
end
