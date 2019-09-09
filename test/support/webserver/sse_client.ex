defmodule Helix.Test.Webserver.SSEClient do

  use GenServer
  use Helix.Test.Webserver

  alias HELL.Utils

  @wait_interval 50
  @initial_state %{
    events: [], ping_count: 0, wait_runs: 0, wait_max: nil, wait_pid: nil
  }

  def start(session) do
    name = Utils.concat_atom("sse_test_", session.session_id)
    GenServer.start_link(__MODULE__, session, name: name)
  end

  def get_recv(session) do
    name = Utils.concat_atom("sse_test_", session.session_id)
    GenServer.call(name, :get)
  end

  def wait_events(pid, events, timeout \\ 1_000) do
    GenServer.cast(pid, {:wait_for, events, self(), timeout})

    receive do
      {:ok, matched_events} ->
        sort_events(events, matched_events)

      {:timeout, matched, missing} ->
        raise "Timeout. Missing: #{inspect missing}. Got: #{inspect matched}"
    end
  end

  defp sort_events(waiting_events, matched_events) do
    Enum.map(waiting_events, fn event_name ->
      Enum.find(matched_events, fn matched_event ->
        String.to_atom(matched_event.event) == event_name
      end)
    end)
  end

  defp on_receive(pid, msg),
    do: GenServer.cast(pid, msg)

  # Callbacks

  def init(session) do
    sse_client_pid = self()

    spawn fn ->
      conn()
      |> infer_path(:subscribe)
      |> set_session(session)
      |> execute_until(:session_handler)
      |> Helix.Webserver.SSE.stream(&(on_receive(sse_client_pid, &1)))
    end

    initial_state = Map.merge(%{session: session}, @initial_state)

    {:ok, initial_state}
  end

  def handle_cast({:wait_for, events, reply_pid, timeout}, state) do
    wait_max = div(timeout, @wait_interval) + 1
    new_state = %{state| wait_runs: 0, wait_max: wait_max, wait_pid: reply_pid}

    {:noreply, wait_for(events, new_state)}
  end

  def handle_cast({:event, %{payload: event}}, state),
    do: {:noreply, %{state| events: [event | state.events]}}

  def handle_cast({:ping, count}, state) do
    monitor_name = "sse_monitor_" <> state.session.session_id |> String.to_atom()
    GenServer.call(monitor_name, :pong)

    {:noreply, %{state| ping_count: state.ping_count + 1}}
  end

  def handle_info({:wait_for, events}, state) do
    new_state = wait_for(events, state)

    {:noreply, %{new_state| wait_runs: state.wait_runs + 1}}
  end

  defp wait_for(events, state) do
    state.events
    |> Enum.reduce({[], events}, fn event, acc = {acc_events, missing_events} ->
      event_name = String.to_atom(event.event)
      if event_name in missing_events do
        {[event | acc_events], Enum.reject(missing_events, &(&1 == event_name))}
      else
        acc
      end
    end)
    |> case do
         {matched_events, []} ->
           # Found all events we were looking for; reply back to the test.
           send(state.wait_pid, {:ok, matched_events})

           # Remove matched events from the `events` entry
           matched_events
           |> Enum.reduce(state, fn event, new_state ->
             %{new_state|
               events: Enum.reject(new_state.events, &(&1 == event))}
           end)

         {matched_events, missing_events} ->
           if state.wait_runs == state.wait_max do
             # Max time reached, let the test know we failed
             send(state.wait_pid, {:timeout, matched_events, missing_events})
           else
             # Not yet, and within the timeout limit, so we'll try again soon...
             Process.send_after(self(), {:wait_for, events}, @wait_interval)
           end

           state
       end
  end
end
