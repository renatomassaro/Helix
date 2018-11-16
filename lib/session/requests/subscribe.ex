defmodule Helix.Session.Requests.Subscribe do

  import Helix.Webserver.Utils

  def check_params(request, session) do
    reply_ok(request)
  end

  def check_permissions(request, _) do
    reply_ok(request)
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
