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

  def endpoint_requires_auth?(_, [_, "register"]),
    do: false
  def endpoint_requires_auth?(_, [_, "login"]),
    do: false
  def endpoint_requires_auth?(_, _),
    do: true

  def is_sync_request?("POST", [_, "sync"]),
    do: true
  def is_sync_request?(_, _),
    do: false

  # def get_identifier_tuple([_, "server", server_cid | _], conn),
  #   do: {get_session_id(conn), get_server_id(server_cid)}
  # def get_identifier_tuple(_, conn),
  #   do: {get_session_id(conn)}

  def get_identifier_tuple([_, "server", server_cid | _], conn),
    do: get_identifier_tuple({:server, get_server_id(server_cid)}, conn)
  def get_identifier_tuple({:server, {:ok, server_id}}, conn),
    do: {:ok, {get_session_id(conn), server_id}}
  def get_identifier_tuple({:server, {:error, _}}, conn),
    do: {:error, :nxnip}
  def get_identifier_tuple(_, conn),
    do: {:ok, {get_session_id(conn)}}

  def get_session_id(%_{assigns: %{session_id: session_id}}),
    do: session_id
  def get_session_id(_),
    do: nil

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
    do: {:ok, server_id}
  defp get_server_id({:nip, {ip, network_id = %Network.ID{}}}),
    do: CacheQuery.from_nip_get_server(network_id, ip)
  defp get_server_id(server_cid) do
    server_cid
    |> parse_server_cid()
    |> get_server_id
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
      {:ok, ip} <- Validator.validate_input(unsafe_ip, :ipv4),
      {:ok, network_id} <- Network.ID.cast(unsafe_network_id)
    do
      {:nip, {ip, network_id}}
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
