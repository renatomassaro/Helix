defmodule Helix.Webserver.HelixController do
  use Helix.Webserver, :controller

  def index(conn = %Plug.Conn{status: code}, _) when is_integer(code),
    do: json(conn, conn.assigns.helix_response)

  # defp generate_payload(conn) do
  #   conn.assigns.helix_response
  #   |> wrap_data()
  #   |> Map.merge(%{meta: generate_meta(conn)})
  # end

  # defp generate_meta(conn) do
  #   %{request_id: :todo}
  # end

  # defp wrap_data(data = %{data: _}),
  #   do: data
  # defp wrap_data(data),
  #   do: %{data: data}
end
