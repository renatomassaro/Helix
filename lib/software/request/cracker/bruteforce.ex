defmodule Helix.Software.Request.Cracker.Bruteforce do

  use Helix.Webserver.Request

  alias HELL.IPv4
  alias Helix.Network.Henforcer.Bounce, as: BounceHenforcer
  alias Helix.Network.Model.Network
  alias Helix.Software.Henforcer.Software.Cracker, as: CrackerHenforcer
  alias Helix.Software.Public.File, as: FilePublic

  def check_params(request, session) do
    target_nip = parse_nip(request.unsafe["target_nip"])

    with \
      {:ok, {unsafe_network_id, unsafe_ip}} <- target_nip,
      {:ok, network_id} <- Network.ID.cast(unsafe_network_id),
      true <- IPv4.valid?(unsafe_ip),
      {:ok, bounce_id} <- validate_bounce(request.unsafe["bounce_id"]),
      true <- session.context.access == :local || :bad_attack_src
    do
      params = %{
        bounce_id: bounce_id,
        network_id: network_id,
        ip: unsafe_ip
      }

      reply_ok(request, params: params)
    else
      :bad_attack_src ->
        bad_request(request, :bad_attack_src)

      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    network_id = request.params.network_id
    source_id = session.context.gateway.server_id
    entity_id = session.entity_id
    bounce_id = request.params.bounce_id
    ip = request.params.ip

    with \
      {true, r1} <- BounceHenforcer.can_use_bounce?(entity_id, bounce_id),
      {true, r2} <-
        CrackerHenforcer.can_bruteforce?(entity_id, source_id, network_id, ip)
    do
      meta = %{
        bounce: r1.bounce,
        gateway: r2.gateway,
        target: r2.target,
        cracker: r2.cracker
      }

      reply_ok(request, meta: meta)
    else
      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, _session) do
    network_id = request.params.network_id
    ip = request.params.ip
    bounce = request.meta.bounce
    cracker = request.meta.cracker
    gateway = request.meta.gateway
    target = request.meta.target
    relay = request.relay

    bruteforce =
      FilePublic.bruteforce(
        cracker, gateway, target, {network_id, ip}, bounce, relay
      )

    case bruteforce do
      {:ok, _process} ->
        reply_ok(request)

      {:error, reason} ->
        internal_error(request, reason)

      _ ->
        internal_error(request)
    end
  end

  render_empty()
end
