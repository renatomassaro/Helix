defmodule Helix.Software.Request.File.Download do

  use Helix.Webserver.Request

  alias Helix.Cache.Local, as: LocalCache
  alias Helix.Software.Model.File
  alias Helix.Software.Model.Storage
  alias Helix.Software.Henforcer.File.Transfer, as: FileTransferHenforcer
  alias Helix.Software.Public.File, as: FilePublic
  alias Helix.Software.Query.Storage, as: StorageQuery

  def check_params(request, session) do
    # Fetches the server's main storage if none were specified
    unsafe_storage_id =
      if Map.has_key?(request.unsafe, "storage_id") do
        request.unsafe["storage_id"]
      else
        StorageQuery.get_main_storage_id(session.context.gateway.server_id)
      end

    with \
      true <- session.context.access == :remote || :bad_access,
      {:ok, file_id} <- File.ID.cast(request.unsafe["file_id"]),
      {:ok, storage_id} <- Storage.ID.cast(unsafe_storage_id)
    do
      params = %{
        file_id: file_id,
        storage_id: storage_id
      }

      reply_ok(request, params: params)
    else
      :bad_access ->
        bad_request(request, :download_self)

      _ ->
        bad_request(request)
    end
  end

  @doc """
  Verifies the permission for the download. Most of the permission logic
  has been delegated to `FileTransferHenforcer.can_transfer?`, check it out.

  This is where we verify the file being downloaded exists, belongs to the
  correct server, the storage belongs to the server, the user has access to
  the storage, etc.
  """
  def check_permissions(request, session) do
    gateway_id = session.context.gateway.server_id
    endpoint_id = session.context.endpoint.server_id
    file_id = request.params.file_id
    storage_id = request.params.storage_id

    can_transfer? =
      FileTransferHenforcer.can_transfer?(
        :download,
        gateway_id,
        endpoint_id,
        storage_id,
        file_id
      )

    case can_transfer? do
      {true, relay} ->
        meta = %{
          gateway: relay.gateway,
          endpoint: relay.endpoint,
          file: relay.file,
          storage: relay.storage
        }

        reply_ok(request, meta: meta)

      {false, reason, _} ->
        forbidden(request, format_reason(reason))
    end
  end

  def handle_request(request, session) do
    file = request.meta.file
    storage = request.meta.storage
    gateway = request.meta.gateway
    endpoint = request.meta.endpoint
    relay = request.relay

    tunnel = LocalCache.get_tunnel(session.context.tunnel.tunnel_id)

    download =
      FilePublic.download(gateway, endpoint, tunnel, storage, file, relay)

    case download do
      {:ok, _process} ->
        reply_ok(request)

      {:error, reason} ->
        internal_error(request, reason)
    end
  end

  render_empty()

  defp format_reason({:file, :not_belongs}),
    do: {:file, :not_found}
  defp format_reason(reason),
    do: reason
end
