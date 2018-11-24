defmodule Helix.Session.Requests.Check do

  import Helix.Webserver.Request

  alias Helix.Webserver.CSRF, as: CSRFWeb
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

  def handle_request(request, session) do
    csrf_token = CSRFWeb.generate_token(session.session_id)

    reply_ok(request, meta: %{csrf_token: csrf_token})
  end

  def render_response(request, _session) do
    csrf_token = request.meta.csrf_token

    respond_ok(request, %{csrf_token: csrf_token})
  end
end
