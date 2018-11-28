defmodule Helix.Log.Request.Recover.Custom do

  use Helix.Webserver.Request

  import HELL.Macros

  alias Helix.Cache.Local, as: LocalCache
  alias Helix.Log.Henforcer.Log.Recover, as: LogRecoverHenforcer
  alias Helix.Log.Model.Log
  alias Helix.Log.Public.Recover, as: RecoverPublic

  def check_params(request, _session) do
    with \
      {:ok, log_id} <- Log.ID.cast(request.unsafe["log_id"])
    do
      reply_ok(request, params: %{log_id: log_id})
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    log_id = request.params.log_id
    gateway_id = session.context.gateway.server_id
    target_id = session.context.endpoint.server_id

    can_recover? =
      LogRecoverHenforcer.can_recover_custom?(log_id, gateway_id, target_id)

    case can_recover? do
      {true, relay} ->
        meta = %{gateway: relay.gateway, recover: relay.recover, log: relay.log}
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
      RecoverPublic.custom(
        gateway, target, request.meta.log, recover, entity_id, conn_info, relay
      )
    end

    reply_ok(request)
  end

  def render_response(request, _session),
    do: respond_empty(request)
end
