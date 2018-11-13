defmodule Helix.Webserver.Plugs.RequestRouter do

  import Plug.Conn

  def init(opts),
    do: opts

  def call(conn, _opts) do
    unsafe_params =
      if conn.method == "GET" do
        conn.params
      else
        conn.body_params
      end

    socket = %{}
    initial_request =
      %{unsafe: unsafe_params,
        params: %{},
        meta: %{},
        response: %{},
        status: nil
       }

    conn
    |> assign(:helix_request, initial_request)
    |> check_params(socket)
    |> check_permissions(socket)
    |> handle_request(socket)
    |> render_response(socket)
    |> put_response()
  end

  defp check_params(conn, socket) do
    conn.assigns.module
    |> apply(:check_params, [conn.assigns.helix_request, socket])
    |> handle_result(conn)
  end

  defp check_permissions(conn = %_{status: s}, _) when not is_nil(s),
    do: conn
  defp check_permissions(conn, socket) do
    conn.assigns.module
    |> apply(:check_permissions, [conn.assigns.helix_request, socket])
    |> handle_result(conn)
  end

  defp handle_request(conn = %_{status: s}, _) when not is_nil(s),
    do: conn
  defp handle_request(conn, socket) do
    conn.assigns.module
    |> apply(:handle_request, [conn.assigns.helix_request, socket])
    |> handle_result(conn)
  end

  defp render_response(conn = %_{status: s}, _) when not is_nil(s),
    do: conn
  defp render_response(conn, socket) do
    conn.assigns.module
    |> apply(:render_response, [conn.assigns.helix_request, socket])
    |> handle_result(conn)
  end

  defp put_response(conn = %_{status: s}) when not is_nil(s),
    do: conn
  defp put_response(conn) do
    conn
    |> put_status(conn.assigns.helix_request.status)
    |> assign(:helix_response, conn.assigns.helix_request.response)
  end

  defp handle_result({:ok, request}, conn),
    do: assign(conn, :helix_request, request)

  defp handle_result({:error, request, reason}, conn) do
    conn
    |> put_status(request.status)
    |> assign(:helix_response, %{error: %{reason: reason}})
  end
end
