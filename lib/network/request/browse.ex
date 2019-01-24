defmodule Helix.Network.Request.Browse do

  use Helix.Webserver.Request

  alias Helix.Server.Model.Server
  alias Helix.Software.Public.PFTP, as: PFTPPublic
  alias Helix.Network.Model.Network
  alias Helix.Network.Henforcer.Network, as: NetworkHenforcer
  alias Helix.Network.Public.Network, as: NetworkPublic

  @internet_id Network.internet_id()

  def check_params(request, session) do
    gateway_id = session.context.gateway.server_id
    endpoint_id = session.context.endpoint.server_id

    origin_id =
      if Map.has_key?(request.unsafe, "origin") do
        request.unsafe["origin"]
      else
        session.context.endpoint.server_id
      end

    with \
      {:ok, address} <- validate_address(request.unsafe["address"]),
      {:ok, origin_id} <- Server.ID.cast(origin_id),
      true <-
        NetworkHenforcer.valid_origin?(origin_id, gateway_id, endpoint_id)
        || :bad_origin
    do
      params = %{address: address, origin: origin_id}
      reply_ok(request, params: params)
    else
      :bad_address ->
        bad_request(request, :bad_address)

      :bad_origin ->
        bad_request(request, :bad_origin)

      _ ->
        bad_request(request)
    end
  end

  # TODO: `origin` is unauthenticated
  def check_permissions(request, _session),
    do: {:ok, request}

  def handle_request(request, session) do
    origin_id = request.params.origin
    address = request.params.address

    network_id =
      if session.context.access == :local do
        @internet_id
      else
        session.context.tunnel.network_id
      end

    case NetworkPublic.browse(network_id, address, origin_id) do
      {:ok, web, relay} ->
        reply_ok(request, meta: %{web: web, relay: relay})

      {:error, _} ->
        not_found(request)
    end
  end

  def render_response(request, _session) do
    web = request.meta.web
    server_id = request.meta.relay.server_id

    [network_id, ip] = web.nip

    pftp_files =
      server_id
      |> PFTPPublic.list_files()
      |> PFTPPublic.render_list_files()

    type =
      if web.subtype do
        to_string(web.type) <> "_" <> to_string(web.subtype)
      else
        to_string(web.type)
      end

    data = %{
      content: web.content,
      type: type,
      meta: %{
        nip: [to_string(network_id), to_string(ip)],
        password: web.password,
        public: pftp_files
      }
    }

    respond_ok(request, data)
  end

  defp validate_address(address) when is_binary(address) do
    # TODO: At least apply a regex here
    {:ok, address}
  end

  defp validate_address(_),
    do: :bad_request
end
