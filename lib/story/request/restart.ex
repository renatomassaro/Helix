defmodule Helix.Story.Request.Restart do

  use Helix.Webserver.Request

  alias Helix.Story.Henforcer.Story, as: StoryHenforcer
  alias Helix.Story.Public.Story, as: StoryPublic
  alias Helix.Story.Request.Utils, as: RequestUtils

  def check_params(request, _session) do
    with \
      {:ok, contact_id} <-
        RequestUtils.cast_contact(request.unsafe["contact_id"])
    do
      reply_ok(request, params: %{contact_id: contact_id})
    else
      {:error, reason = :bad_contact} ->
        bad_request(request, reason)

      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    contact_id = request.params.contact_id
    entity_id = session.entity_id

    case StoryHenforcer.can_restart?(entity_id, contact_id) do
      {true, relay} ->
        meta = %{step: relay.step, checkpoint: relay.checkpoint}
        reply_ok(request, meta: meta)

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, _session) do
    step = request.meta.step
    checkpoint = request.meta.checkpoint

    case StoryPublic.restart(step, checkpoint) do
      :ok ->
        reply_ok(request)

      _ ->
        internal_error(request)
    end
  end

  render_empty()
end
