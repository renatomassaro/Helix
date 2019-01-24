defmodule Helix.Software.Request.PFTP.Server.Disable do
  @moduledoc """
  PFTPServerDisableRequest is called when the player wants to disable his
  PublicFTP server.
  """

  use Helix.Webserver.Request

  alias Helix.Software.Henforcer.File, as: FileHenforcer
  alias Helix.Software.Public.PFTP, as: PFTPPublic

  @doc """
  All PFTP requests, including `pftp.file.download`, must be performed on the
  local session.
  """
  def check_params(request, session) do
    if session.context.access == :local do
      reply_ok(request)
    else
      bad_request(request, :pftp_must_be_local)
    end
  end

  @doc """
  Most or all permissions are delegated to PFTPHenforcer.
  """
  def check_permissions(request, session) do
    entity_id = session.entity_id
    server_id = session.context.gateway.server_id

    case FileHenforcer.PublicFTP.can_disable_server?(entity_id, server_id) do
      {true, relay} ->
        meta = %{pftp: relay.pftp}
        reply_ok(request, meta: meta)

      {false, reason, _} ->
        forbidden(request, format_reason(reason))
    end
  end

  def handle_request(request, _session) do
    pftp = request.meta.pftp

    case PFTPPublic.disable_server(pftp) do
      {:ok, _pftp} ->
        reply_ok(request)

      {:error, reason} ->
        internal_error(request, reason)
    end
  end

  @doc """
  Renders an empty response. Client will receive only a successful return code.

  Client shall soon receive a PFTPServerDisabledEvent.
  """
  render_empty()

  defp format_reason({:pftp, :disabled}),
    do: :pftp_already_disabled
  defp format_reason(reason),
    do: reason
end
