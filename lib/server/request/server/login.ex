defmodule Helix.Server.Request.Server.Login do

  use Helix.Webserver.Request

  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Network.Henforcer.Bounce, as: BounceHenforcer
  alias Helix.Network.Henforcer.Network, as: NetworkHenforcer
  alias Helix.Server.Henforcer.Channel, as: ChannelHenforcer
  alias Helix.Server.Henforcer.Server, as: ServerHenforcer
  alias Helix.Server.Model.Server
  alias Helix.Server.Public.Index, as: ServerIndex
  alias Helix.Server.Public.Server, as: ServerPublic

  def check_params(request, session) do
    endpoint_nip = parse_nip(request.unsafe["endpoint_nip"])

    with \
      {:ok, gateway_id} <- Server.ID.cast(request.unsafe["gateway_id"]),

      # Validate the given NIP
      {:ok, {unsafe_network_id, unsafe_ip}} <- endpoint_nip,
      {:ok, network_id, ip} <- validate_nip(unsafe_network_id, unsafe_ip),

      # Validate password
      {:ok, password} <-
        validate_input(request.unsafe["password"], :server_password),

      # Validate bounce
      {:ok, bounce_id} <- validate_bounce(request.unsafe["bounce_id"])
    do
      params = %{
        network_id: network_id,
        gateway_id: gateway_id,
        endpoint_ip: ip,
        password: password,
        bounce_id: bounce_id
      }

      reply_ok(request, params: params)
    else
      {false, reason, _} ->
        bad_request(request, reason)

      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    entity_id = session.entity_id
    password = request.params.password
    network_id = request.params.network_id
    gateway_id = request.params.gateway_id
    endpoint_ip = request.params.endpoint_ip
    bounce_id = request.params.bounce_id

    remote_join_allowed? = fn gateway, endpoint ->
      ChannelHenforcer.remote_join_allowed?(
        entity_id, gateway, endpoint, password
      )
    end

    with \
      {true, r1} <- ServerHenforcer.server_exists?(gateway_id),
      gateway = r1.server,
      {true, r2} <- NetworkHenforcer.nip_exists?(network_id, endpoint_ip),
      endpoint = r2.server,
      endpoint_entity = EntityQuery.fetch_by_server(endpoint.server_id),
      {true, r3} <- remote_join_allowed?.(gateway, endpoint),
      gateway_entity = r3.entity,
      {true, r4} <- BounceHenforcer.can_use_bounce?(gateway_entity, bounce_id),
      bounce = r4.bounce
    do
      meta = %{
        gateway: gateway,
        endpoint: endpoint,
        gateway_entity: gateway_entity,
        endpoint_entity: endpoint_entity,
        bounce: bounce
      }

      reply_ok(request, meta: meta)
    else
      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, session) do
    network_id = request.params.network_id
    endpoint_ip = request.params.endpoint_ip
    bounce = request.meta.bounce
    relay = request.relay

    gateway = request.meta.gateway
    endpoint = request.meta.endpoint
    gateway_entity = request.meta.gateway_entity
    endpoint_entity = request.meta.endpoint_entity

    with \
      {:ok, tunnel, ssh} <-
          ServerPublic.connect_to_server(
            network_id, gateway.server_id, endpoint.server_id, bounce, relay
          )
    do
      bootstrap =
        endpoint
        |> ServerIndex.remote(gateway.server_id, gateway_entity.entity_id)
        |> ServerIndex.render_remote(endpoint, gateway_entity.entity_id)

      reply_ok(request, meta: %{bootstrap: bootstrap})
    else
      {:error, reason} ->
        internal_error(request, reason)
    end
  end

  def render_response(request, session) do
    bootstrap = request.meta.bootstrap

    respond_ok(request, bootstrap)
  end
end
