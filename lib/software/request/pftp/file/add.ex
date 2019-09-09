defmodule Helix.Software.Request.PFTP.File.Add do
  @moduledoc """
  PFTPFileAddRequest is called when the player wants to add a file to her PFTP.
  """

  use Helix.Webserver.Request

  alias Helix.Software.Model.File
  alias Helix.Software.Henforcer.File, as: FileHenforcer
  alias Helix.Software.Public.PFTP, as: PFTPPublic

  @doc """
  All PFTP requests must be performed on the local context.
  """
  def check_params(request, session) do
    with \
      true <- session.context.access == :local || :not_local,
      {:ok, file_id} <- File.ID.cast(request.unsafe["file_id"])
    do
      params = %{
        file_id: file_id
      }

      reply_ok(request, params: params)
    else
      :not_local ->
        bad_request(request, :pftp_must_be_local)

      _ ->
        bad_request(request)
    end
  end

  @doc """
  Most or all permissions are delegated to PFTPHenforcer.
  """
  def check_permissions(request, session) do
    entity_id = session.entity_id
    server_id = session.context.gateway.server_id
    file_id = request.params.file_id

    case FileHenforcer.PublicFTP.can_add_file?(entity_id, server_id, file_id) do
      {true, relay} ->
        meta = %{
          pftp: relay.pftp,
          file: relay.file
        }

        reply_ok(request, meta: meta)

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, _session) do
    pftp = request.meta.pftp
    file = request.meta.file

    case PFTPPublic.add_file(pftp, file) do
      {:ok, _pftp_file} ->
        reply_ok(request)

      {:error, reason} ->
        internal_error(request, reason)
    end
  end

  render_empty()
end