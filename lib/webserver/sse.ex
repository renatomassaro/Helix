defmodule Helix.Webserver.SSE do

  import Plug.Conn

  alias Helix.Core.Node.Manager, as: NodeManager
  alias Helix.Session.State.SSE.API, as: SSEStateAPI
  alias Helix.Session.State.SSE.Monitor, as: SSEStateMonitor
  alias Helix.Webserver.Session, as: SessionWeb

  @node_id NodeManager.get_node_name()
  @keepalive_ttl 100000

  def stream(conn, listen_callback \\ nil) do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    # Send a message now; otherwise client waits for first ping
    sse_push(conn, first_blood())

    session_id = SessionWeb.get_session_id!(conn)

    # Link connection pid to the current session
    SSEStateAPI.link_sse(session_id, @node_id, self())

    # Monitor this process and the SSEState GenServer as well, making sure both
    # are always up-to-date. It is also responsible for sending ping requests to
    # the client.
    SSEStateMonitor.start_and_monitor(session_id, self())

    conn
    |> listen(listen_callback)
    |> halt()
  end

  defp listen(conn, cb) do
    receive do
      msg = {:event, payload} ->
        execute_callback(cb, msg)
        conn
        |> sse_push(prepare_msg(payload))
        |> listen(cb)

      msg = {:ping, count} ->
        execute_callback(cb, msg)
        conn
        |> sse_push(ping_msg(count))
        |> listen(cb)

      {:plug_conn, :sent} ->
        listen(conn, cb)

      e ->
        IO.puts "Unexpected message: #{inspect e}"
    end

    conn
  end

  defp sse_push(conn, msg) do
    {:ok, conn} = chunk(conn, msg)
    conn
  end

  defp ping_msg(count) do
    "data: {\"ping\": #{count}}\n\n"
  end

  defp prepare_msg(payload) do
    stringified_payload = Poison.encode!(payload)
    "data: #{stringified_payload}\n\n"
  end

  defp first_blood do
    retry_interval = Enum.random(2000..10000)
    "retry: #{retry_interval}\ndata: {\"phoebe\": \"rulez\"}\n\n"
  end

  defp execute_callback(nil, _),
    do: :noop
  defp execute_callback(callback, msg) when is_function(callback),
    do: spawn fn -> callback.(msg) end
end