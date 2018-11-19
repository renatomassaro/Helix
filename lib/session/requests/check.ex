defmodule Helix.Session.Requests.Check do

  import Helix.Webserver.Utils

  alias Helix.Session.State.SSE.API, as: SSEStateAPI

  def check_params(request, _session),
    do: reply_ok(request)

  def check_permissions(request, session) do
    if SSEStateAPI.has_sse_active?(session.session_id) do
      forbidden(request, :already_online)
    else
      reply_ok(request)
    end
  end

  def handle_request(request, _session),
    do: reply_ok(request)

  def render_response(request, _session),
    do: respond_empty(request, 200)
end
