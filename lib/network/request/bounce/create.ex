defmodule Helix.Network.Request.Bounce.Create do

  use Helix.Webserver.Request

  import HELL.Macros

  alias Helix.Network.Henforcer.Bounce, as: BounceHenforcer
  alias Helix.Network.Public.Bounce, as: BouncePublic
  alias Helix.Network.Request.Bounce.Utils, as: BounceRequestUtils

  def check_params(request, _session) do
    with \
      {:ok, name} <- validate_input(request.unsafe["name"], :bounce_name),
      {:ok, links} <- BounceRequestUtils.cast_links(request.unsafe["links"])
    do
      params = %{name: name, links: links}
      reply_ok(request, params: params)
    else
      reason = :bad_link ->
        bad_request(request, reason)

      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    entity_id = session.entity_id
    name = request.params.name
    links = request.params.links

    can_create_bounce =
      BounceHenforcer.can_create_bounce?(entity_id, name, links)

    case can_create_bounce do
      {true, relay} ->
        reply_ok(request, meta: %{servers: relay.servers})

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, session) do
    entity_id = session.entity_id
    name = request.params.name
    links = request.params.links
    servers = request.meta.servers
    relay = request.relay

    links = BounceRequestUtils.merge_links(links, servers)

    hespawn fn ->
      BouncePublic.create(entity_id, name, links, relay)
    end

    reply_ok(request)
  end

  render_empty()
end
