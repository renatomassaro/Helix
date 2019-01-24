defmodule Helix.Software.Request.PFTP.File.Download do

  use Helix.Webserver.Request

  alias Helix.Cache.Query.Cache, as: CacheQuery
  alias Helix.Network.Model.Tunnel
  alias Helix.Software.Model.File
  alias Helix.Software.Model.Storage
  alias Helix.Software.Henforcer.File, as: FileHenforcer
  alias Helix.Software.Public.PFTP, as: PFTPPublic
  alias Helix.Software.Query.Storage, as: StorageQuery

  def check_params(request, session) do
    unsafe_storage_id =
      if Map.has_key?(request.unsafe, "storage_id") do
        request.unsafe["storage_id"]
      else
        StorageQuery.get_main_storage(session.context.gateway.server_id)
      end

    endpoint_nip = parse_nip(request.unsafe["endpoint_nip"])

    with \
      true <- session.context.access == :remote || :not_remote,
      {:ok, {unsafe_network_id, unsafe_ip}} <- endpoint_nip,
      {:ok, network_id, ip} <- validate_nip(unsafe_network_id, unsafe_ip),
      {:ok, file_id} <- File.ID.cast(request.unsafe["file_id"]),
      {:ok, target_id} <- CacheQuery.from_nip_get_server(network_id, ip),
      {:ok, storage_id} <- Storage.ID.cast(unsafe_storage_id)
    do
      params = %{
        file_id: file_id,
        storage_id: storage_id,
        target_id: target_id,
        network_id: network_id
      }

      reply_ok(request, params: params)
    else
      :not_remote ->
        bad_request(request, :pftp_must_be_remote)

      {:error, {:nip, :notfound}} ->
        bad_request(request, :nip_not_found)

      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    server_id = session.context.gateway.server_id
    target_id = request.params.target_id
    storage_id = request.params.storage_id
    file_id = request.params.file_id
    network_id = request.params.network_id

    can_transfer? =
      FileHenforcer.Transfer.can_transfer?(
        :download, server_id, target_id, storage_id, file_id
      )

    with \
      {true, r1} <- can_transfer?,
       # /\ Ensures we can download the file
      file = r1.file,
      endpoint = r1.endpoint,
      gateway = r1.gateway,

      # Make sure the file exists on a PublicFTP server
      {true, _} <- FileHenforcer.PublicFTP.file_exists?(endpoint, file),

      # PFTP downloads must happen either on the Internet or on Story network
      {true, _} <- FileHenforcer.PublicFTP.valid_network?(network_id)
    do
      meta = %{
        gateway: gateway,
        endpoint: endpoint,
        file: file,
        storage: r1.storage,
        network_id: network_id
      }

      reply_ok(request, meta: meta)
    else
      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, _session) do
    gateway = request.meta.gateway
    endpoint = request.meta.endpoint
    file = request.meta.file
    storage = request.meta.storage
    relay = request.relay

    # TODO: Check??????????????????????????????????????????????????????????????
    # PFTP download is always on the `local` server, so there's no bounce - and
    # no actual tunnel. This is a "fake tunnel" that should let us workaround
    # this edge case
    fake_tunnel =
      %Tunnel{
        network_id: request.meta.network_id,
        bounce_id: nil
      }

    download =
      PFTPPublic.download(
        gateway, endpoint, storage, file, fake_tunnel, relay
      )

    case download do
      {:ok, process} ->
        reply_ok(request)

      {:error, reason} ->
        internal_error(request, reason)
    end
  end

  render_empty()
end
