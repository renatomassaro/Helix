defmodule Helix.Story.Action.Flow.StoryTest do

  use Helix.Test.Case.Integration

  import ExUnit.CaptureLog

  alias Helix.Story.Action.Flow.Story, as: StoryFlow
  alias Helix.Story.Query.Story, as: StoryQuery
  alias Helix.Story.Model.Steppable

  alias Helix.Test.Entity.Helper, as: EntityHelper
  alias Helix.Test.Story.Helper, as: StoryHelper
  alias Helix.Test.Story.Setup, as: StorySetup

  describe "send_reply/3" do
    test "sends the reply when everything is valid" do
      {_, %{entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_steps@test_msg, meta: %{})

      [%{entry: entry, object: step}] = StoryQuery.get_steps(entity_id)
      reply_id = StoryHelper.get_allowed_reply(entry)

      # `reply_to_e1` emits a log once handled, so we are capturing it here to
      # avoid the Log output from polluting the test results.
      capture_log(fn ->
        assert :ok = StoryFlow.send_reply(entity_id, step.contact, reply_id)
      end)
    end

    test "fails when step is not found (wrong contact)" do
      {_, %{entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_steps@test_msg, meta: %{})

      [%{entry: entry}] = StoryQuery.get_steps(entity_id)
      reply_id = StoryHelper.get_allowed_reply(entry)

      # Correct entity, correct reply_id, but wrong contact.
      assert {:error, :bad_step} ==
        StoryFlow.send_reply(entity_id, StoryHelper.contact_id(), reply_id)
    end

    test "fails when reply does not exist" do
      {_, %{step: step, entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_steps@test_msg, meta: %{})

      reply_id = "locked_reply_to_e1"

      assert {:error, reason} =
        StoryFlow.send_reply(entity_id, step.contact, reply_id)
      assert reason == {:reply, :not_found}
    end

    test "fails when player is not in a mission" do
      assert {:error, :bad_step} ==
        StoryFlow.send_reply(
          EntityHelper.id(),
          StoryHelper.contact_id(),
          "reply_id"
        )
    end
  end

  describe "restart/2" do
    test "restarts the step" do
      {story_step, %{entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_restart@test_restart, meta: %{})

      # We'll reply to the first message
      StoryHelper.reply(story_step)

      # There were 3 messages exchanges; last one is "c_msg2"
      [%{object: step, entry: story_step}] = StoryQuery.get_steps(entity_id)
      assert length(story_step.emails_sent) == 3
      assert List.last(story_step.emails_sent) == "c_msg2"

      # Hasn't been restarted yet
      refute story_step.meta["restarted?"]

      {true, checkpoint} = Steppable.checkpoint_find(step, "c_msg2")

      # Let's get it restarted in here
      assert :ok == StoryFlow.restart(step, checkpoint)

      [%{entry: story_step}] = StoryQuery.get_steps(entity_id)

      # Removed previously sent emails
      assert story_step.emails_sent == ["c_msg1"]
      assert story_step.allowed_replies == ["p_msg1"]

      # Updated meta
      assert story_step.meta["restarted?"]
    end
  end
end
