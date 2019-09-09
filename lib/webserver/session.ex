defmodule Helix.Webserver.Session do

  import Plug.Conn

  alias Helix.Cache.Query.Cache, as: CacheQuery
  alias Helix.Core.Validator
  alias Helix.Network.Model.Network
  alias Helix.Server.Model.Server

  @session_key "sHEssion"
  @session_opts [secure: true, http_only: true]

  def create_session(conn, session_id),
    do: put_resp_cookie(conn, @session_key, session_id, @session_opts)

  def destroy_session(conn),
    do: delete_resp_cookie(conn, @session_key, @session_opts)

  def fetch_session(conn = %_{assigns: %{session_id: _}}),
    do: conn
  def fetch_session(conn) do
    case fetch_session_cookie(conn) do
      nil ->
        case fetch_session_header(conn) do
          nil ->
            conn

          session_id ->
            assign(conn, :session_id, session_id)
        end

      session_id ->
        assign(conn, :session_id, session_id)
    end
  end

  def trim_session(session, context) do
    session
    |> Map.put(:context, context)
    |> Map.drop([:servers, :account])
  end

  def endpoint_requires_auth?(_, [_, "account", "register"]),
    do: false
  def endpoint_requires_auth?(_, [_, "account", "check-username"]),
    do: false
  def endpoint_requires_auth?(_, [_, "account", "check-email"]),
    do: false
  def endpoint_requires_auth?(_, [_, "account", "verify"]),
    do: false
  def endpoint_requires_auth?("GET", [_, "document", "tos"]),
    do: false
  def endpoint_requires_auth?("GET", [_, "document", "pp"]),
    do: false
  def endpoint_requires_auth?(_, [_, "login"]),
    do: false
  def endpoint_requires_auth?(_, _),
    do: true

  def is_sync_request?("POST", [_, "sync"]),
    do: true
  def is_sync_request?("GET", [_, "account", "check-verify"]),
    do: true
  def is_sync_request?("POST", [_, "document", "tos", "sign"]),
    do: true
  def is_sync_request?("POST", [_, "document", "pp", "sign"]),
    do: true
  def is_sync_request?(_, _),
    do: false

  def get_identifier_tuple([_, "server", server_cid | _], conn),
    do: get_identifier_tuple({:server, get_server_id(server_cid)}, conn)
  def get_identifier_tuple([_, "gateway", gateway_id | _], conn),
    do: get_identifier_tuple({:gateway, get_server_id(gateway_id)}, conn)
  def get_identifier_tuple([_, "endpoint", endpoint_nip, "login"], conn) do
    {:ok, {get_session_id(conn)}}
  end
  def get_identifier_tuple([_, "endpoint", endpoint_nip | _], conn),
    do: get_identifier_tuple({:endpoint, get_server_id(endpoint_nip)}, conn)
  def get_identifier_tuple({:server, {:ok, _, server_id}}, conn),
    do: {:ok, {get_session_id(conn), server_id}}
  def get_identifier_tuple({:server, {:error, _}}, conn),
    do: {:error, :nxnip}
  def get_identifier_tuple({:gateway, {:ok, :id, gateway_id}}, conn),
    do: {:ok, {get_session_id(conn), gateway_id}}
  def get_identifier_tuple({:gateway, _}, conn),
    do: {:error, :invalid_id}
  def get_identifier_tuple({:endpoint, {:ok, :nip, endpoint_id}}, conn),
    do: {:ok, {get_session_id(conn), endpoint_id}}
  def get_identifier_tuple({:endpoint, _}, conn),
    do: {:error, :invalid_nip}
  def get_identifier_tuple(_, conn),
    do: {:ok, {get_session_id(conn)}}

  def get_session_id(%_{assigns: %{session_id: session_id}}),
    do: session_id
  def get_session_id(_),
    do: nil
  def get_session_id!(conn),
    do: get_session_id(conn) || raise "session_id missing"

  defp fetch_session_header(conn) do
    case get_req_header(conn, "authorization") do
      [session_id] ->
        verify_session_id(session_id)

      [] ->
        nil
    end
  end

  defp fetch_session_cookie(conn),
    do: verify_session_id(conn.req_cookies[@session_key])

  defp verify_session_id(nil),
    do: nil
  defp verify_session_id(session_id),
    do: verify_session_id(session_id, String.length(session_id))
  defp verify_session_id(session_id, 36),
    do: session_id
  defp verify_session_id(_, _),
    do: nil

  defp get_server_id({:id, server_id = %Server.ID{}}),
    do: {:ok, :id, server_id}

  defp get_server_id({:nip, {network_id = %Network.ID{}, ip}}) do
    case CacheQuery.from_nip_get_server(network_id, ip) do
      {:ok, server_id} ->
        {:ok, :nip, server_id}
      _ ->
        {:error, :nxnip}
    end
  end

  defp get_server_id({:error, reason}),
    do: {:error, reason}

  defp get_server_id(server_cid) do
    server_cid
    |> parse_server_cid()
    |> get_server_id()
  end

  ### Parse cid

  def parse_server_cid(server_cid) when is_binary(server_cid) do
    if String.contains?(server_cid, "$") do
      server_cid
      |> String.split("$")
      |> parse_server_nip()
    else
      server_cid
      |> String.split(",")
      |> parse_server_id(server_cid)
    end
  end

  def parse_server_cid(_),
    do: {:error, :invalid_server_cid}

  defp parse_server_nip([unsafe_ip, "*"]),
    do: parse_server_nip([unsafe_ip, "::"])
  defp parse_server_nip([unsafe_ip, unsafe_network_id]) do
    with \
      unsafe_network_id = String.replace(unsafe_network_id, ",", ":"),
      {:ok, ip} <- Validator.validate_input(unsafe_ip, :ipv4),
      {:ok, network_id} <- Network.ID.cast(unsafe_network_id)
    do
      {:nip, {network_id, ip}}
    else
      _ ->
        {:error, :invalid_server_nip}
    end
  end

  defp parse_server_nip(_),
    do: {:error, :invalid_server_nip}

  defp parse_server_id([_, _, _, _, _, _, _, _], unsafe_server_id) do
    with \
      unsafe_server_id = String.replace(unsafe_server_id, ",", ":"),
      {:ok, server_id} <- Server.ID.cast(unsafe_server_id)
    do
      {:id, server_id}
    else
      _ ->
        {:error, :invalid_server_id}
    end
  end

  defp parse_server_id(_, _),
    do: {:error, :invalid_server_id}
end
