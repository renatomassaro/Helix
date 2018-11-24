defmodule Helix.Webserver.Plugs.Entrypoint do

  import Plug.Conn

  alias Helix.Webserver.Session, as: SessionWeb

  def init(opts),
    do: opts

  def call(conn, _opts) do
    # TODO: Check req-hearders for `content-type` json. Deny otherwise.
    conn
    |> put_resp_header("content-type", "application/json; charset=utf-8")
    |> put_url_params(conn.path_info)
    |> fetch_cookies()
    |> SessionWeb.fetch_session()
  end

  defp put_url_params(conn, [_, "server", server_cid, "log", log_id | _]),
    do: put_params(conn, [{:server_cid, server_cid}, {:log_id, log_id}])
  defp put_url_params(conn, [_, "server", server_cid | _]),
    do: put_params(conn, [{:server_cid, server_cid}])
  defp put_url_params(conn, _),
    do: conn

  defp put_params(conn, param_args) do
    Enum.reduce(param_args, conn, fn {key, value}, acc_conn ->
      %{acc_conn| params: Map.put(acc_conn.params, to_string(key), fmt(value))}
    end)
  end

  defp fmt(binary),
    do: String.replace(binary, ",", ":")
end
