defmodule Helix.Session.Request.Subscribe do

  import Helix.Webserver.Request

  alias Helix.Session.State.SSE.API, as: SSEStateAPI

  def check_params(request, session) do
    reply_ok(request)
  end

  def check_permissions(request, session) do
    if SSEStateAPI.has_sse_active?(session.session_id) do
      forbidden(request, :already_online)
    else
      reply_ok(request)
    end
  end

  def handle_request(request, _) do
    request
    |> start_subscription()
    |> reply_ok()
  end

  def render_response(request, session) do
    respond_ok(request, %{})
  end
end
