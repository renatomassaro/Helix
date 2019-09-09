defmodule Helix.Story.Model.SteppableTest do

  use Helix.Test.Case.Integration

  alias Helix.Story.Model.Steppable

  alias Helix.Test.Story.Helper, as: StoryHelper
  alias Helix.Test.Story.Setup, as: StorySetup

  describe "checkpoint_find/2" do
    test "returns the corresponding checkpoint" do
      {step, %{entity_id: entity_id}} =
        StorySetup.step(name: :fake_restart@test_restart, meta: %{})

      # `p_msg2` should go up to `c_msg1`
      assert {true, {message_id, _}} = Steppable.checkpoint_find(step, "p_msg2")
      assert message_id == "c_msg1"

      # `c_arc1_msg2` should go up to `c_msg1`
      assert {true, {message_id, _}} =
        Steppable.checkpoint_find(step, "c_arc1_msg2")
      assert message_id == "c_msg1"

      # `c_msg3` is a checkpoint itself
      assert {true, {message_id, _}} = Steppable.checkpoint_find(step, "c_msg3")
      assert message_id == "c_msg3"

      # `p_msg3` should go up to `c_msg3`
      assert {true, {message_id, _}} =
        Steppable.checkpoint_find(step, "p_msg3")
      assert message_id == "c_msg3"
    end
  end
end
