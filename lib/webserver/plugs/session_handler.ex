defmodule Helix.Webserver.Plugs.SessionHandler do

  import Plug.Conn
  import Helix.Webserver.Plugs.Utils

  alias Helix.Session.State.Session.API, as: SessionStateAPI
  alias Helix.Webserver.Session, as: SessionWeb

  def init(opts),
    do: opts

  def call(conn, _opts) do
    with \
      true <-
        SessionWeb.endpoint_requires_auth?(conn.method, conn.path_info)
        || :noauth,
      true <- is_binary(SessionWeb.get_session_id(conn)) || :nxsession,
      synced? = not SessionWeb.is_sync_request?(conn.method, conn.path_info),
      {:ok, id_tuple} <- SessionWeb.get_identifier_tuple(conn.path_info, conn),
      {:ok, state, context} <-
        SessionStateAPI.check_permission(id_tuple, synced?: synced?)
    do
      conn
      |> assign(:session, Map.put(state, :context, context))
      |> flag_as_authenticated()
    else
      # Public endpoint
      :noauth ->
        conn
        |> assign(:session, %{})
        |> flag_as_authenticated()

      # Missing session cookie/header
      reason = :nxsession ->
        halt_error(conn, reason)

      {:error, :nxnip} ->
        halt_error(conn, :nxserver, 404)

      # Failed SessionStateAPI check
      {:error, reason} ->
        halt_error(conn, reason)
    end
  end

  defp flag_as_authenticated(conn),
    do: assign(conn, :request_authenticated?, true)

  defp halt_error(conn, reason, status \\ 403) do
    conn
    |> resp(status, json_body(%{error: %{reason: reason}}))
    |> halt()
  end
end
