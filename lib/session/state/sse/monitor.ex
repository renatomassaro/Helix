defmodule Helix.Session.State.SSE.Monitor do

  use GenServer

  alias Helix.Webserver.CSRF, as: CSRFWeb
  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Session.State.SSE.API, as: SSEStateAPI

  @ping_interval 30_000  # 30s
  @pong_timeout 5_000  # 5s
  @csrf_refresh_interval 300_000  # 5m

  # Public API

  @doc """
  Public API to start the SSEStateMonitor GenServer and monitor the SSEState
  process.
  """
  def start_and_monitor(session_id, conn_pid) do
    # FIXME: Atom exhaustion warning: This leaks 1 atom per user login.
    sse_name = SSEStateAPI.get_process_name(session_id)
    name = "sse_monitor_" <> session_id |> String.to_atom()

    # Starts the SSEStateMonitor GenServer, as identified by `name`. The named
    # registry is required so the Ping response knows whom to call.
    {:ok, pid} = GenServer.start_link(__MODULE__, [], name: name)

    # Adds to the Monitor the corresponding session/sse data.
    GenServer.call(pid, {:setup, session_id, sse_name, conn_pid})
  end

  # Callbacks

  def init(_) do
    # Trap exit from the parent process, so `terminate/2` gets called if/when
    # the SSE stream process crashes or closes.
    Process.flag(:trap_exit, true)

    {:ok, %{}}
  end

  @doc """
  Stores the existing session data, most notably the SSE connection pid so it
  can be sent to the SSEState shall it crash. It also stores initial ping
  information.
  """
  def handle_call({:setup, session_id, sse_name, conn_pid}, _from, _state) do
    state =
      %{
        sse_name: sse_name,
        session_id: session_id,
        conn_pid: conn_pid,
        ping: %{
          count: 1,
          last_sent: nil,
          last_reply: nil,
          timeout_timer: nil
        }
      }

    # Starts the ping loop
    monitor_client()

    # Monitors the SSEState GenServer, so if it crashes the existing SSE stream
    # pid can be sent to the new SSEState GenServer.
    monitor_sse_state(state)

    # Automatically refresh the client's CSRF token every few minutes
    monitor_csrf_token()

    {:reply, :ok, state}
  end

  @doc """
  Handles the client ping response, removing the existing timeout timer (which
  would stop this GenServer and mark the user offline) and requesting that a new
  ping request be sent in `@ping_interval` milliseconds.
  """
  def handle_call(:pong, _from, state = %{ping: %{timeout_timer: nil}}),
    do: {:reply, :ok, state}
  def handle_call(:pong, _from, state) do
    # Cancel existing timer
    Process.cancel_timer(state.ping.timeout_timer)

    # Send a ping request in `@ping_interval` seconds
    monitor_client()

    new_ping =
      %{
        state.ping|
        timeout_timer: nil,
        last_reply: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      }

    {:reply, :ok, %{state| ping: new_ping}}
  end

  @doc """
  When `:ping_client` is received, we are supposed to send a ping request to the
  client using the SSE stream. The client then is responsible for sending back
  a reply, proving it's alive.

  At the same time the ping request is sent, a `:pong_timeout` timer is created.
  If the timer reaches its end before receiving a reply from the client, the
  GenServer will receive the `:pong_timeout` info and stop itself, killing the
  SSE stream and marking the user as offline.

  On the other hand, if the client replies in time (defined by `@pong_timeout`),
  the existing timer is deleted and a new ping request will be sent again to the
  client in `@ping_interval` milliseconds.
  """
  def handle_info(:ping_client, state) do
    # Responsiveness of the client and server. Calculates the RTT and the time
    # taken for the server/client to handle the request/response.
    responsiveness =
      if is_nil(state.ping.last_sent) do
        0
      else
        state.ping.last_reply - state.ping.last_sent
      end

    # Send the ping request with the calculated responsiveness
    send(state.conn_pid, {:ping, responsiveness})

    # Fire the timeout timer that will disconnect the user if a response is not
    # received in `@pong_timeout` milliseconds
    timeout_timer = Process.send_after(self(), :pong_timeout, @pong_timeout)

    new_ping =
      %{state.ping|
        count: state.ping.count + 1,
        timeout_timer: timeout_timer,
        last_sent: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
       }

    {:noreply, %{state| ping: new_ping}}
  end

  @doc """
  When the Monitor receives the `:pong_timeout` message, our client is no longer
  answering the pings and, as such, is considered offline. We must then delete
  the SSE stream (if it's still up) and possibly other disconnect-related stuff.
  """
  def handle_info(:pong_timeout, state),
    do: {:stop, :pong_timeout, state}

  def handle_info(:refresh_csrf, state) do
    new_csrf_token = CSRFWeb.generate_token(state.session_id)

    spawn fn ->
      send(state.conn_pid, {:event, %{event: "renew_csrf", token: new_csrf_token}})
    end

    monitor_csrf_token()

    {:noreply, state}
  end

  @doc """
  When the Monitor receives a `:DOWN` signal, it means the monitored process has
  crashed. The monitored process in this case is the SSEState shard with the
  underlying session information.

  The SSE GenServer will automatically be restarted with an empty state state,
  and will eventually receive the incoming sessions' data, but we need to
  inform what is the existing SSE Stream PID. (Note: The SSEState genserver has
  crashed, the SSE connection didn't).

  Since this information (the SSE pid) is local and not stored on the database,
  we (SSEStateMonitor) are responsible to making sure SSEState receives the
  corresponding SSE connection pid.
  """
  def handle_info({:DOWN, _, _, _, _}, state) do
    # Poor man's back pressure control
    :timer.sleep(Enum.random(10..99))

    # Add the existing SSE connection pid to the newly started SSEState
    SSEStateAPI.put(state.session_id, state.conn_pid)

    # Monitor the new SSEState GenServer
    monitor_sse_state(state)

    {:noreply, state}
  end

  @doc """
  If it's terminating, it's either because the SSE stream was closed or it ended
  abruptly (crashed). In either case, we have to remove the Conn PID from the
  SSEState and make sure this node is no longer listed at the Database as a SSE
  streaming endpoint.
  """
  def terminate(reason, state) do
    # Remove the SSE stream pid from the SSEState
    SSEStateAPI.remove(state.session_id)

    # Update the database so it no longer marks this node as holding this
    # session's SSE stream.
    SessionAction.unlink_sse(state.session_id)
  end

  defp monitor_client do
    Process.send_after(self(), :ping_client, @ping_interval)
  end

  defp monitor_csrf_token do
    Process.send_after(self(), :refresh_csrf, @csrf_refresh_interval)
  end

  defp monitor_sse_state(state) do
    state
    |> get_sse_pid()
    |> Process.monitor()
  end

  defp get_sse_pid(%{sse_name: sse_name}),
    do: Process.whereis(sse_name)
end
