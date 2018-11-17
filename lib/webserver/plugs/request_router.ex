defmodule Helix.Webserver.Plugs.RequestRouter do

  import Plug.Conn

  alias Helix.Webserver.Session, as: SessionWeb
  alias Helix.Webserver.SSE, as: SSEWeb

  def init(opts),
    do: opts

  def call(conn, _opts) do
    # TODO: Check req-hearders for `content-type` json. Deny otherwise.

    unless conn.assigns.request_authenticated?,
      do: raise "unhandled_request"

    unsafe_params =
      if conn.method == "GET" do
        conn.params
      else
        conn.body_params
      end

    initial_request =
      %{
        unsafe: unsafe_params,
        params: %{},
        meta: %{},
        response: %{},
        status: nil,
        __special__: []
       }

    conn
    |> assign(:helix_request, initial_request)
    |> check_params()
    |> check_permissions()
    |> handle_request()
    |> render_response()
    |> handle_special()
    |> put_response()
  end

  defp check_params(conn = %_{assigns: assigns}) do
    assigns.module
    |> apply(:check_params, [assigns.helix_request, assigns.session])
    |> handle_result(conn)
  end

  defp check_permissions(conn = %_{status: s}) when not is_nil(s),
    do: conn
  defp check_permissions(conn = %_{assigns: assigns}) do
    assigns.module
    |> apply(:check_permissions, [assigns.helix_request, assigns.session])
    |> handle_result(conn)
  end

  defp handle_request(conn = %_{status: s}) when not is_nil(s),
    do: conn
  defp handle_request(conn = %_{assigns: assigns}) do
    assigns.module
    |> apply(:handle_request, [assigns.helix_request, assigns.session])
    |> handle_result(conn)
  end

  defp render_response(conn = %_{status: s}) when not is_nil(s),
    do: conn
  defp render_response(conn = %_{assigns: assigns}) do
    assigns.module
    |> apply(:render_response, [assigns.helix_request, assigns.session])
    |> handle_result(conn)
  end

  defp handle_special(conn = %_{assigns: %{helix_request: %{__special__: []}}}),
    do: conn
  defp handle_special(conn = %Plug.Conn{}) do
    conn.assigns.helix_request.__special__
    |> Enum.reduce(conn, &(handle_special(&1, &2)))
  end

  # Move somewhere lese?
  #
  defp handle_special(%{action: :create, session_id: session_id}, conn),
    do: SessionWeb.create_session(conn, session_id)
  defp handle_special(%{action: :start_subscription}, conn),
    do: SSEWeb.stream(conn)

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
