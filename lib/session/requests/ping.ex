defmodule Helix.Session.Requests.Ping do

  import Helix.Webserver.Request

  alias HELL.Utils
  alias Helix.Session.State.SSE.API, as: SSEStateAPI

  def check_params(request, _session) do
    reply_ok(request, params: request.unsafe)
  end

  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, session) do
    pid =
      "sse_monitor_"
      |> Utils.concat_atom(session.session_id)
      |> Process.whereis()

    with \
      true <- is_pid(pid),
      true <- Process.alive?(pid)
    do
      GenServer.call(pid, :pong)
    end

    reply_ok(request)
  end

  def render_response(request, _session),
    do: respond_empty(request)
end
