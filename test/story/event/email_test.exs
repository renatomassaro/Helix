defmodule Helix.Story.Event.EmailTest do

  use Helix.Test.Case.Integration

  alias Helix.Test.Channel.Setup, as: ChannelSetup
  alias Helix.Test.Event.Helper.Trigger.Publishable, as: PublishableHelper
  alias Helix.Test.Event.Setup, as: EventSetup

  describe "Publishable.whom_to_publish/1" do
    test "publishes only to the player" do
      event = EventSetup.Story.email_sent()

      publish = PublishableHelper.whom_to_publish(event)
      assert publish == %{account: event.entity_id}
    end
  end

  describe "Publishable.generate_payload/1" do
    test "generates the payload" do
      socket = ChannelSetup.mock_account_socket()

      event = EventSetup.Story.email_sent()

      assert {:ok, data} = PublishableHelper.generate_payload(event, socket)

      assert data.step == to_string(event.step.name)
      assert data.email_id == event.email.id
      assert is_binary(data.contact_id)
      assert data.meta
      assert data.replies
      assert is_float(data.timestamp)

      assert "story_email_sent" == PublishableHelper.get_event_name(event)
    end
  end
end
