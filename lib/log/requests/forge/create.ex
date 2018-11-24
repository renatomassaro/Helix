defmodule Helix.Log.Requests.Forge.Create do

  use Helix.Webserver.Request

  import HELL.Macros

  alias Helix.Cache.Local, as: LocalCache
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Log.Henforcer.Log.Forge, as: LogForgeHenforcer
  alias Helix.Log.Public.Forge, as: ForgePublic
  alias Helix.Log.Requests.Forge.Utils, as: ForgeRequestUtils

  def check_params(request, _session) do
    with \
      {:ok, log_info} <-
        ForgeRequestUtils.cast_log_info(
          request.unsafe["log_type"], request.unsafe["log_data"]
        )
    do
      reply_ok(request, params: %{log_info: log_info})
    else
      {:error, reason} ->
        bad_request(request, reason)
    end
  end

  def check_permissions(request, session) do
    gateway_id = session.context.gateway.server_id

    case LogForgeHenforcer.can_create?(gateway_id) do
      {true, relay} ->
        meta = %{gateway: relay.gateway, forger: relay.forger}
        reply_ok(request, meta: meta)

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, session) do
    log_info = request.params.log_info
    forger = request.meta.forger
    gateway = request.meta.gateway
    relay = nil  # TODO
    # relay = request.relay

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
      ForgePublic.create(gateway, target, log_info, forger, conn_info, relay)
    end

    reply_ok(request)
  end

  def render_response(request, _),
    do: respond_empty(request)
end
