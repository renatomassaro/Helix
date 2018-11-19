defmodule Helix.Account.Requests.Logout do

  import Helix.Webserver.Utils

  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Session.State.Session.API, as: SessionStateAPI

  def check_params(request, _session),
    do: reply_ok(request)

  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, session) do
    # User explicitly logged out, so we have to invalidate her session
    SessionAction.delete(session.session_id)

    # And since the session no longer exists, remove it from this server
    SessionStateAPI.delete(session.session_id)

    # Note that the SessionState process from other Helix nodes may still hold
    # the recently invalidated session in cache for a while.
    # SessionState will automatically remove the session information after 10
    # minutes, regardless if it is being used or not.
    # That means that, if we do not notify other Helix nodes, the session may
    # still be marked as valid for up to 10 minutes.
    # This is sort-of OK for now, but can easily be fixed in the future if we
    # deem necessary by using `pg_notify` or something like that.

    request

    # Makes sure the httpOnly cookie gets deleted on the client.
    |> destroy_session()
    |> reply_ok()
  end

  def render_response(request, _session),
    do: respond_empty(request)
end
