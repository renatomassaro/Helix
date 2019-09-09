defmodule Helix.Story.Henforcer.StoryTest do

  use Helix.Test.Case.Integration

  import Helix.Test.Henforcer.Macros

  alias Helix.Story.Model.Steppable
  alias Helix.Story.Query.Story, as: StoryQuery
  alias Helix.Story.Henforcer.Story, as: StoryHenforcer

  alias Helix.Test.Entity.Helper, as: EntityHelper
  alias Helix.Test.Story.Helper, as: StoryHelper
  alias Helix.Test.Story.Setup, as: StorySetup

  describe "step_exists?/2" do
    test "accepts when step exists" do
      {story_step, %{entity_id: entity_id, step: step}} =
        StorySetup.story_step(name: :fake_steps@test_msg, meta: %{})

      assert {true, relay} =
        StoryHenforcer.step_exists?(entity_id, story_step.contact_id)
      assert_relay relay, [:step, :story_step]

      assert relay.story_step == story_step
      assert relay.step == step
    end

    test "rejects when step does not exist" do
      assert {false, reason, _} =
        StoryHenforcer.step_exists?(EntityHelper.id(), StoryHelper.contact_id())
      assert reason == {:step, :not_found}
    end
  end

  describe "can_restart?/2" do
    test "accepts when can restart" do
      {story_step, %{entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_restart@test_restart, meta: %{})

      # Reply once, so we are not on the first message (which is a checkpoint).
      StoryHelper.reply(story_step)

      # Query again, since after the reply above the story structs have changed
      [%{object: step, entry: story_step}] = StoryQuery.get_steps(entity_id)
      {true, expected_checkpoint} = Steppable.checkpoint_find(step, "c_msg2")

      assert {true, relay} =
        StoryHenforcer.can_restart?(entity_id, story_step.contact_id)
      assert_relay relay, [:step, :story_step, :checkpoint]

      assert relay.story_step == story_step
      assert relay.step == step
      assert relay.checkpoint == expected_checkpoint
    end

    test "rejects when already on checkpoint" do
      {story_step, %{entity_id: entity_id}} =
        StorySetup.story_step(name: :fake_restart@test_restart, meta: %{})

      # We are on the very first msg (`c_msg1`), which is a checkpoint, so we
      # can't restart the step
      assert {false, reason, _} =
        StoryHenforcer.can_restart?(entity_id, story_step.contact_id)

      assert reason == {:already, :checkpoint}
    end
  end
end
