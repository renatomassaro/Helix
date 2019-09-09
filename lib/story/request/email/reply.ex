defmodule Helix.Story.Request.Email.Reply do

  use Helix.Webserver.Request

  alias Helix.Story.Public.Story, as: StoryPublic
  alias Helix.Story.Request.Utils, as: RequestUtils

  def check_params(request, _session) do
    with \
      {:ok, reply_id} <- validate_input(request.unsafe["reply_id"], :reply_id),
      {:ok, contact_id} <-
        RequestUtils.cast_contact(request.unsafe["contact_id"])
    do
      params = %{
        reply_id: reply_id,
        contact_id: contact_id
      }

      reply_ok(request, params: params)
    else
      {:error, reason = :bad_contact} ->
        bad_request(request, reason)

      _ ->
        bad_request(request)
    end
  end

  @doc """
  Permissions whether that reply is valid within the player's current context
  are checked at StoryPublic- and StoryAction-level
  """
  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, session) do
    entity_id = session.entity_id
    reply_id = request.params.reply_id
    contact_id = request.params.contact_id

    case StoryPublic.send_reply(entity_id, contact_id, reply_id) do
      :ok ->
        reply_ok(request)

      {:error, reason} ->
        internal_error(request, reason)
    end
  end

  def render_response(request, _session),
    do: respond_empty(request)
end
