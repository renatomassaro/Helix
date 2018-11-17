defmodule Helix.Webserver.SSE do

  import Plug.Conn

  # alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Session.State.SSE.API, as: SSEStateAPI
  alias Helix.Webserver.Session, as: SessionWeb

  @node_id :bra_helix_of9dm
  @keepalive_ttl 100000

  def stream(conn) do
    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> send_chunked(200)

    # Send a message now; otherwise client waits for first ping
    sse_push(conn, ping_msg(0))

    # Save connection pid on SessionState

    # session_id
    # |> SessionWeb.get_session_id()
    # |> SessionAction.link_sse(@node_name)

    conn
    |> SessionWeb.get_session_id!()
    |> SSEStateAPI.link_sse(@node_id, self())

    #
    # SSEStateAPI.fetch_sse(session_id)

    # SSEWebMap.monitor(session_id, self())

    ping_loop(1)

    conn
    |> listen()
    |> halt()
  end

  defp listen(conn) do
    receive do
      {:ping, count} ->
        ping_loop(count + 1)
        conn
        |> sse_push(ping_msg(count))
        |> listen()

      {:plug_conn, :sent} ->
        listen(conn)

      # {:DOWN....}

      # TODO: `:close` not really needed because of monitor...
      :close ->
        :ok

      e ->
        IO.puts "GOT WTF"
        IO.inspect(e)
        # raise "asdf"
    end

    IO.puts "FINISHEDD"
    conn
  end

  defp sse_push(conn, msg) do
    {:ok, conn} = chunk(conn, msg)
    conn
  end

  defp ping_msg(count) do
    "data: {\"ping\": #{count}}\n\n"
  end

  defp ping_loop(count) do
    new_ref = Process.send_after(self(), {:ping, count}, @keepalive_ttl)
    old_ref = Process.put(:timer_ref, new_ref)
    unless is_nil(old_ref),
      do: Process.cancel_timer(old_ref)
    :ok
  end
end
