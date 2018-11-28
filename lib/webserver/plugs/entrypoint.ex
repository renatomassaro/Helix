defmodule Helix.Webserver.Plugs.Entrypoint do

  import Plug.Conn
  import Helix.Webserver.Plugs.Utils

  alias Helix.Webserver.Session, as: SessionWeb

  @cf_client_header "cf-connecting-ip"
  @env Application.get_env(:helix, :env)

  def init(opts),
    do: opts

  def call(conn, _opts) do
    # TODO: Check req-hearders for `content-type` json. Deny otherwise.
    conn
    |> put_resp_header("content-type", "application/json; charset=utf-8")
    |> put_url_params(conn.path_info)
    |> put_client_ip()
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

  defp put_client_ip(conn) do
    {client_binary_ip, client_inet_ip} = get_client_ip(conn)

    conn
    |> assign(:client_ip, client_binary_ip)
    |> Map.replace!(:remote_ip, client_inet_ip)
  end

  defp get_client_ip(conn) do
    case get_req_header(conn, @cf_client_header) do
      [ip] ->
        case :inet_parse.strict_address(ip) do
          {:ok, inet_ip} ->
            {ip, inet_ip}

          {:error, _} ->
            halt_error(conn, :invalid_client_data, 400)
        end

      [] ->
        if @env == :prod do
          halt_error(conn, :missing_client_data, 407)
        else
          case :inet_parse.ntoa(conn.remote_ip) do
            ip when is_list(ip) ->
              {to_string(ip), conn.remote_ip}

            {:error, _} ->
              halt_error(conn, :invalid_client_data, 400)
          end
        end
    end
  end

  defp fmt(binary),
    do: String.replace(binary, ",", ":")
end
