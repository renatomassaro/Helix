defmodule Helix.Log.Request.Recover.Global do
  @moduledoc """
  `LogRecoverRequest` is called when the player wants to recover a log. It may
  either be a `global` recovery, in which case a recoverable log is randomly
  selected from all logs within the server, or it may be a `custom` recovery,
  in which case a specific log to be recovered is defined by the player.
  """

  use Helix.Webserver.Request

  import HELL.Macros

  alias Helix.Cache.Local, as: LocalCache
  alias Helix.Log.Henforcer.Log.Recover, as: LogRecoverHenforcer
  alias Helix.Log.Public.Recover, as: RecoverPublic

  def check_params(request, _session),
    do: reply_ok(request)

  def check_permissions(request, session) do
    gateway_id = session.context.gateway.server_id

    case LogRecoverHenforcer.can_recover_global?(gateway_id) do
      {true, relay} ->
        meta = %{gateway: relay.gateway, recover: relay.recover}
        reply_ok(request, meta: meta)

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, session) do
    entity_id = session.entity_id
    recover = request.meta.recover
    gateway = request.meta.gateway
    relay = request.relay

    {target, conn_info} =
      if session.context.access == :local do
        {gateway, nil}
      else
        endpoint = LocalCache.get_server(session.context.endpoint.server_id)
        tunnel = LocalCache.get_tunnel(session.context.tunnel.tunnel_id)
        ssh = LocalCache.get_connection(session.context.ssh.connection_id)

        {endpoint, {tunnel, ssh}}
      end

    hespawn fn ->
      RecoverPublic.global(
        gateway, target, recover, entity_id, conn_info, relay
      )
    end

    reply_ok(request)
  end

  def render_response(request, _session),
    do: respond_empty(request)
end
