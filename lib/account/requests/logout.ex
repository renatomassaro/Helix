defmodule Helix.Account.Requests.Logout do

  import Helix.Webserver.Utils

  alias Helix.Session.State.SSE.API, as: SSEStateAPI

  def check_params(request, _session),
    do: reply_ok(request)

  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, session) do
    SSEStateAPI.close(session.session_id)

    reply_ok(request)
  end

  def render_response(request, _session) do
    respond_empty(request)
  end

end
