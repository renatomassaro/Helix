defmodule Helix.Log.Request.Forge.Edit do

  import Helix.Webserver.Request

  import HELL.Macros

  alias Helix.Cache.Local, as: LocalCache
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Log.Model.Log
  alias Helix.Log.Henforcer.Log.Forge, as: LogForgeHenforcer
  alias Helix.Log.Public.Forge, as: ForgePublic
  alias Helix.Log.Request.Forge.Utils, as: ForgeRequestUtils

  def check_params(request, _session) do
    with \
      {:ok, log_id} <- Log.ID.cast(request.unsafe["log_id"]),
      {:ok, log_info} <-
        ForgeRequestUtils.cast_log_info(
          request.unsafe["log_type"], request.unsafe["log_data"]
        )
    do
      reply_ok(request, params: %{log_id: log_id, log_info: log_info})
    else
      {:error, reason} ->
        bad_request(request, reason)

      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    log_id = request.params.log_id
    gateway_id = session.context.gateway.server_id
    target_id = session.context.endpoint.server_id

    case LogForgeHenforcer.can_edit?(log_id, gateway_id, target_id) do
      {true, relay} ->
        meta = %{gateway: relay.gateway, forger: relay.forger, log: relay.log}
        reply_ok(request, meta: meta)

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, session) do
    log_info = request.params.log_info
    forger = request.meta.forger
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
      entity_id = session.entity_id
      log = request.meta.log

      ForgePublic.edit(
        gateway, target, log, log_info, forger, entity_id, conn_info, relay
      )
    end

    reply_ok(request)
  end

  def render_response(request, _),
    do: respond_empty(request)
end
