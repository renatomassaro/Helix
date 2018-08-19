defmodule Helix.Log.Event.LogTest do

  use Helix.Test.Case.Integration

  alias Helix.Event.Publishable

  alias Helix.Test.Channel.Setup, as: ChannelSetup
  alias Helix.Test.Event.Setup, as: EventSetup

  @mocked_socket ChannelSetup.mock_server_socket()

  describe "LogCreatedEvent" do
    test "Publishable.generate_payload/2" do
      event = EventSetup.Log.created()

      # Generates the payload
      assert {:ok, data} = Publishable.generate_payload(event, @mocked_socket)

      # Returned payload and json-friendly
      assert data.log_id == to_string(event.log.log_id)
      assert data.type == to_string(event.log.revision.type)
      assert data.data
      assert is_float(data.timestamp)

      # Returned event is correct
      assert "log_created" == Publishable.get_event_name(event)
    end

    test "Publishable.whom_to_publish/1" do
      event = EventSetup.Log.created()
      assert %{server: server_id} = Publishable.whom_to_publish(event)
      assert server_id == event.log.server_id
    end
  end

  describe "LogRevisedEvent" do
    test "Publishable.generate_payload/2" do
      event = EventSetup.Log.revised()

      # Generates the payload
      assert {:ok, data} = Publishable.generate_payload(event, @mocked_socket)

      # Returned payload is json-friendly
      assert data.log_id == to_string(event.log.log_id)
      assert data.type == to_string(event.log.revision.type)
      assert data.data
      assert is_float(data.timestamp)

      # Returned event is correct
      assert "log_revised" == Publishable.get_event_name(event)
    end
  end

  describe "LogDestroyedEvent" do
    test "Publishable.generate_payload/2" do
      event = EventSetup.Log.destroyed()

      # Generates the payload
      assert {:ok, data} = Publishable.generate_payload(event, @mocked_socket)

      # Returned payload is json-friendly
      assert data.log_id == to_string(event.log.log_id)

      # Returned event is correct
      assert "log_destroyed" == Publishable.get_event_name(event)
    end
  end
end
