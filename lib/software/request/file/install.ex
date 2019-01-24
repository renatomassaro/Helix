defmodule Helix.Software.Request.File.Install do

  use Helix.Webserver.Request

  import HELL.Macros

  alias Helix.Cache.Local, as: LocalCache
  alias Helix.Server.Henforcer.Server, as: ServerHenforcer
  alias Helix.Software.Henforcer.File, as: FileHenforcer
  alias Helix.Software.Henforcer.Virus, as: VirusHenforcer
  alias Helix.Software.Model.File
  alias Helix.Software.Public.File, as: FilePublic

  alias Helix.Software.Process.File.Install, as: FileInstallProcess

  def check_params(request, _session) do
    with {:ok, file_id} <- File.ID.cast(request.unsafe["file_id"]) do
      params = %{file_id: file_id}

      reply_ok(request, params: params)
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    entity_id = session.entity_id
    gateway_id = session.context.gateway.server_id
    target_id = session.context.endpoint.server_id
    file_id = request.params.file_id

    with \
      {true, r1} <- FileHenforcer.Install.can_install?(file_id, entity_id),
      {true, %{server: gateway}} <- ServerHenforcer.server_exists?(gateway_id),
      {true, %{server: target}} <- ServerHenforcer.server_exists?(target_id)
    do
      file = r1.file
      relay = Map.merge(r1, %{gateway: gateway, target: target})

      backend = FileInstallProcess.get_backend(file)
      check_permissions_backend(backend, request, relay)
    else
      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  defp check_permissions_backend(:virus, request, relay) do
    case VirusHenforcer.can_install?(relay.file, relay.entity) do
      {true, r2} ->
        meta =
          relay
          |> Map.merge(r2)
          |> Map.merge(%{backend: :virus})

        reply_ok(request, meta: meta)

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  # TODO: This does not support local installations
  def handle_request(request, session) do
    file = request.meta.file
    gateway = request.meta.gateway
    backend = request.meta.backend
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
      FilePublic.install(file, gateway, target, backend, conn_info, relay)
    end

    reply_ok(request)
  end

  render_empty()
end
