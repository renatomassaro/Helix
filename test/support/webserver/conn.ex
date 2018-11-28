defmodule Helix.Test.Webserver.Conn do

  import Plug.Conn

  alias Plug.Conn
  alias HELL.ClientUtils
  alias HELL.Utils
  alias Helix.Session.Model.Session

  alias Helix.Test.Webserver.Helper, as: WebserverHelper

  @pipelines %{
    api: [
      :entrypoint,
      :request_id,
      :csrf_handler,
      :session_handler,
      :request_id,
      :request_router
    ]
  }

  # Conn query

  def get_request_id(conn),
    do: conn.assigns.request_id

  def get_response(conn),
    do: conn.assigns.helix_response

  # Conn setup

  def conn do
    Plug.Adapters.Test.Conn.conn(%Conn{}, "GET", "placeholder", %{})
    |> Map.put(:host, initial_host())
    |> Map.put(:req_headers, initial_headers())
    |> put_private(:skip_csrf, true)
  end

  def set_method(conn, method),
    do: %{conn| method: method}

  def infer_path(conn, path_id, args \\ []) when is_atom(path_id),
    do: set_path(conn, WebserverHelper.path(path_id, Utils.ensure_list(args)))

  def set_path(conn, {method, path, module}) do
    conn
    |> set_method(method)
    |> set_path(List.flatten(path))
    |> set_module(module)
  end
  def set_path(conn, path) when is_list(path),
    do: %{conn| path_info: path, request_path: "/" <> Enum.join(path, "/")}

  def set_module(conn, module),
    do: assign(conn, :module, module)

  def set_session(conn, session),
    do: put_cookie(conn, "sHEssion", session.session_id)

  def set_session_id(conn, session_id) do
    conn
    |> assign(:session, %{session_id: session_id})
    |> assign(:session_id, session_id)
    |> assign(:request_authenticated?, true)
    |> put_private(:skip_session, true)
  end

  def put_cookie(conn, key, value) do
    stringified_value = "#{key}=#{value}"
    current_value = get_req_header(conn, "cookie")

    new_value =
      if Enum.empty?(current_value) do
        stringified_value
      else
        List.first(current_value) <> "; #{stringified_value}"
      end

    put_req_header(conn, "cookie", new_value)
  end

  def put_body(conn, body) do
    %{conn|
      params: body,
      body_params: body
    }
  end

  # Request handling

  def execute(conn, pipeline \\ :api) do
    Enum.reduce(@pipelines[pipeline], conn, fn plug_id, conn ->
      cond do
        conn.halted ->
          conn

        plug_id == :csrf_handler and skip_csrf?(conn) ->
          conn

        plug_id == :session_handler and skip_session?(conn) ->
          conn

        :else ->
          apply(get_plug(plug_id), :call, [conn, %{}])
      end
    end)
  end

  def execute_until(conn, plug_limit_id, pipe \\ :api) do
    Enum.reduce(@pipelines[pipe], {conn, false}, fn plug_id, {conn, stop?} ->
      cond do
        # If `stop?` flag active, do not proceed
        stop? ->
          {conn, stop?}

        conn.halted ->
          {conn, true}

        plug_id == :csrf_handler and skip_csrf?(conn) ->
          {conn, stop?}

        plug_id == :session_handler and skip_session?(conn) ->
          {conn, stop?}

        # Execute and set `stop?` flag if it's executing the `plug_limit_id`
        :else ->
          {
            apply(get_plug(plug_id), :call, [conn, %{}]),
            plug_id == plug_limit_id
          }
      end
    end)
    |> elem(0)
  end

  # Utils

  defdelegate to_cid(id),
    to: ClientUtils

  # Private

  defp get_plug(:entrypoint),
    do: Helix.Webserver.Plugs.Entrypoint
  defp get_plug(:csrf_handler),
    do: Helix.Webserver.Plugs.CSRFHandler
  defp get_plug(:session_handler),
    do: Helix.Webserver.Plugs.SessionHandler
  defp get_plug(:request_id),
    do: Helix.Webserver.Plugs.RequestID
  defp get_plug(:request_router),
    do: Helix.Webserver.Plugs.RequestRouter

  defp skip_csrf?(%{private: %{skip_csrf: true}}),
    do: true
  defp skip_csrf?(_),
    do: false

  defp skip_session?(%{private: %{skip_session: true}}),
    do: true
  defp skip_session?(_),
    do: false

  defp initial_headers do
    [
      {"accept", "application/json"},
      {"accept-encoding", "gzip, deflate, br"},
      {"accept-language", "en-US,en;q=0.5"},
      {"content-type", "application/json"},
      {"origin", "https://play.hackerexperience.com/"},
      {"referer", "https://play.hackerexperience.com/"},
      {"user-agent",
       "Mozilla/5.0 (X11; FreeBSD amd64; rv:63.0) Gecko/20100101 Firefox/63.0"}
    ]
  end

  defp initial_host,
    do: "https://api.hackerexperience.com"
end
