defmodule Helix.Network.Request.Bounce.Update do

  use Helix.Webserver.Request

  import HELL.Macros

  alias Helix.Network.Model.Bounce
  alias Helix.Network.Henforcer.Bounce, as: BounceHenforcer
  alias Helix.Network.Public.Bounce, as: BouncePublic
  alias Helix.Network.Request.Bounce.Utils, as: BounceRequestUtils

  def check_params(request, _session) do
    name =
      if request.unsafe["name"] do
        validate_input(request.unsafe["name"], :bounce_name)
      else
        {:ok, nil}
      end

    links =
      if request.unsafe["links"] do
        BounceRequestUtils.cast_links(request.unsafe["links"])
      else
        {:ok, nil}
      end

    with \
      {:ok, bounce_id} <- Bounce.ID.cast(request.unsafe["bounce_id"]),
      {:ok, new_name} <- name,
      {:ok, new_links} <- links,

      # At least one of `name, links` must be updated
      true <- not is_nil(new_name) or not is_nil(new_links)
    do
      params =
        %{
          bounce_id: bounce_id,
          new_name: new_name,
          new_links: new_links
        }

      reply_ok(request, params: params)
    else
      :bad_link ->
        bad_request(request, :bad_link)

      false ->
        bad_request(request, :no_changes)

      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    entity_id = session.entity_id
    bounce_id = request.params.bounce_id
    new_name = request.params.new_name
    new_links = request.params.new_links

    can_update_bounce =
      BounceHenforcer.can_update_bounce?(
        entity_id, bounce_id, new_name, new_links
      )

    case can_update_bounce do
      {true, relay} ->
        meta =
          %{
            entity: relay.entity,
            bounce: relay.bounce,
            servers: relay.servers
          }

        reply_ok(request, meta: meta)

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, _session) do
    bounce = request.meta.bounce
    relay = request.relay

    new_name = request.params.new_name
    new_link =
      if request.params.new_links do
        BounceRequestUtils.merge_links(
          request.params.new_links, request.meta.servers
        )
      else
        nil
      end

    hespawn fn ->
      BouncePublic.update(bounce, new_name, new_link, relay)
    end

    reply_ok(request)
  end

  render_empty()
end
