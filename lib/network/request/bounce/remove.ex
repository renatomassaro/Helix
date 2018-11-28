defmodule Helix.Network.Request.Bounce.Remove do

  use Helix.Webserver.Request

  import HELL.Macros

  alias Helix.Network.Model.Bounce
  alias Helix.Network.Henforcer.Bounce, as: BounceHenforcer
  alias Helix.Network.Public.Bounce, as: BouncePublic

  def check_params(request, _session) do
    with {:ok, bounce_id} <- Bounce.ID.cast(request.unsafe["bounce_id"]) do
      reply_ok(request, params: %{bounce_id: bounce_id})
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    entity_id = session.entity_id
    bounce_id = request.params.bounce_id

    case BounceHenforcer.can_remove_bounce?(entity_id, bounce_id) do
      {true, relay} ->
        reply_ok(request, meta: %{bounce: relay.bounce})

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, _session) do
    bounce = request.meta.bounce
    relay = request.relay

    hespawn fn ->
      BouncePublic.remove(bounce, relay)
    end

    reply_ok(request)
  end

  render_empty()
end
