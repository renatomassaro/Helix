defmodule Helix.Story.Event.Email do

  import Hevent

  event Sent do
    @moduledoc """
    `StoryEmailSentEvent` is fired when a Contact (Storyline character) sends an
    email to the Player.
    """

    alias Helix.Entity.Model.Entity
    alias Helix.Story.Model.Step
    alias Helix.Story.Model.Story

    @type t ::
      %__MODULE__{
        entity_id: Entity.id,
        step: Step.t,
        email: Story.Email.email
      }

    event_struct [:entity_id, :step, :email]

    @spec new(Step.t, Story.Email.email) ::
      t
    def new(step = %_{name: _, meta: _, entity_id: _}, email = %{id: _}) do
      %__MODULE__{
        entity_id: step.entity_id,
        step: step,
        email: email
      }
    end

    trigger Publishable do
      @moduledoc """
      Logic of the event that will be published to the client once the event
      `StoryEmailSentEvent` is fired.
      """

      use Helix.Event.Trigger.Publishable.Macros

      alias HELL.ClientUtils

      event_name :story_email_sent

      def generate_payload(event) do
        contact_id = Step.get_contact(event.step) |> to_string()
        replies =
          event.step
          |> Step.get_replies_of(event.email.id)
          |> Enum.map(&to_string/1)

        progress =
          case Step.get_email(event.step, event.email.id) do
            reply = %{} ->
              reply.progress

            nil ->
              nil
          end

        data = %{
          step: to_string(event.step.name),
          contact_id: contact_id,
          replies: replies,
          email_id: event.email.id,
          meta: event.email.meta,
          progress: progress,
          timestamp: ClientUtils.to_timestamp(event.email.timestamp)
        }

        {:ok, data}
      end

      @doc """
      Publish to the player on his own channel.
      """
      def whom_to_publish(event),
        do: %{account: event.entity_id}
    end
  end
end
