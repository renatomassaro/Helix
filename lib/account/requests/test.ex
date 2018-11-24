defmodule Helix.Account.Requests.Test do

  import Helix.Webserver.Request

  alias Helix.Event
  alias Helix.Log.Event.Log.Created, as: LogCreatedEvent
  alias Helix.Log.Query.Log, as: LogQuery

  def check_params(request, session) do
    reply_ok(request)
  end

  def check_permissions(request, session) do
    reply_ok(request)
  end

  def handle_request(request, session) do
    event =
      session.context.gateway.server_id
      |> LogQuery.get_logs_on_server()
      |> List.first()
      |> LogCreatedEvent.new()

    Event.emit(event)

    reply_ok(request)
  end

  def render_response(request, session) do
    respond_empty(request)
  end

end
