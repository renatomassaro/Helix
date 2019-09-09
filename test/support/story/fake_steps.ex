defmodule Helix.Test.Story.StepHelper do

  alias Helix.Test.Entity.Helper, as: EntityHelper

  def all_steps do
    [
      %{
        name: :fake_steps@test_meta,
        meta: %{foo: :bar, id: EntityHelper.id()}
      },
      %{
        name: :fake_steps@test_simple,
        meta: %{}
      },
      %{
        name: :fake_steps@test_one,
        meta: %{step: :one}
      },
      %{
        name: :fake_steps@test_two,
        meta: %{step: :two}
      },
      %{
        name: :fake_steps@test_counter,
        meta: %{i: 0}
      }
    ]
  end

  def random_step,
    do: Enum.random(all_steps())

  def get_contact,
    do: :test_contact
end

defmodule Helix.Story.Mission.FakeSteps do

  import Helix.Story.Model.Step.Macros

  contact :test_contact

  step TestMeta do

    @messages []
    @checkpoints %{}

    alias Helix.Entity.Model.Entity

    empty_setup()

    def start(step),
      do: {:ok, step, [], []}

    def complete(step),
      do: {:ok, step, []}

    @doc """
    Meta format:
    %{
      foo: :bar,
      entity_id: Entity.id,
    }
    """
    def format_meta(%{meta: meta}) do
      %{
        foo: String.to_existing_atom(meta["foo"]),
        id: Entity.ID.cast!(meta["id"])
      }
    end

    next_step __MODULE__
  end

  step TestSimple do

    @messages []
    @checkpoints %{}

    empty_setup()

    def start(step),
      do: {:ok, step, [], []}

    def complete(step),
      do: {:ok, step, []}

    next_step __MODULE__
  end

  step TestOne do

    @messages []
    @checkpoints %{}

    empty_setup()

    def start(step),
      do: {:ok, step, [], []}

    def complete(step),
      do: {:ok, step, []}

    def format_meta(%{meta: meta}),
      do: %{step: String.to_existing_atom(meta["step"])}

    next_step Helix.Story.Mission.FakeSteps.TestTwo
  end

  step TestTwo do

    @messages []
    @checkpoints %{}

    empty_setup()

    def start(step),
      do: {:ok, step, [], []}

    def complete(step),
      do: {:ok, step, []}

    def format_meta(%{meta: meta}),
      do: %{step: String.to_existing_atom(meta["step"])}

    next_step __MODULE__
  end

  step TestCounter do

    @messages []
    @checkpoints %{}

    empty_setup()

    def start(step),
      do: {:ok, step, [], []}

    def complete(step),
      do: {:ok, step, []}

    def format_meta(%{meta: meta}),
      do: %{i: meta["i"]}

    next_step __MODULE__
  end

  step TestMsg do

    require Logger

    @messages []
    @checkpoints %{}

    email "e1",
      replies: ["reply_to_e1"],
      locked: ["locked_reply_to_e1"]

    email "e2",
      replies: ["reply_to_e2"]

    email "e3",
      replies: ["reply_to_e3"]

    on_reply "reply_to_e1" do
      Logger.warn "replied_to_e1"
    end

    on_reply "reply_to_e2",
      send: "e3"

    on_reply "reply_to_e3",
      do: :complete

    empty_setup()

    def start(step) do
      send_email step, "e1"
      {:ok, step, [], []}
    end

    def complete(step),
      do: {:ok, step, []}

    next_step Helix.Story.Mission.FakeSteps.TestSimple
  end

  step TestMsgFlow do

    @messages []
    @checkpoints %{}

    email "e1",
      replies: ["reply_to_e1"]

    on_reply "reply_to_e1",
      send: "e2"

    email "e2",
      replies: ["reply_to_e2"]

    on_reply "reply_to_e2",
      send: "e3"

    email "e3",
      replies: ["reply_to_e3"]

    on_reply "reply_to_e3",
      do: :complete

    empty_setup()

    def start(step) do
      send_email step, "e1"
      {:ok, step, [], []}
    end

    def complete(step),
      do: {:ok, step, []}

    next_step __MODULE__
  end
end

defmodule Helix.Story.Mission.FakeContactOne do

  import Helix.Story.Model.Step.Macros

  contact :contact_one

  step TestSimple do

    @messages []
    @checkpoints %{}

    empty_setup()

    def start(step),
      do: {:ok, step, [], []}

    def complete(step),
      do: {:ok, step, []}

    next_step __MODULE__
  end
end

defmodule Helix.Story.Mission.FakeContactTwo do

  import Helix.Story.Model.Step.Macros

  contact :contact_two

  step TestSimple do

    @messages []
    @checkpoints %{}

    empty_setup()

    def start(step),
      do: {:ok, step, [], []}

    def complete(step),
      do: {:ok, step, []}

    next_step __MODULE__
  end
end

defmodule Helix.Story.Mission.FakeRestart do

  import Helix.Story.Model.Step.Macros

  contact :contact_restart

  step TestRestart do

    @messages ["c_msg1",
               "p_msg1",
               "c_msg2",
               "p_msg2",
               "p_arc1_msg2",
               "c_arc1_msg2",
               "c_msg3",
               "p_msg3"]

    @checkpoints %{
      "c_msg1" => {nil},
      "c_msg3" => {nil}
    }

    email "c_msg1",
      replies: "p_msg1"

    on_reply "p_msg1",
      send: "c_msg2"

    email "c_msg2",
      replies: ["p_msg2", "p_arc1_msg2"]

    on_reply "p_msg2",
      send: "c_msg_3"

    on_reply "p_arc1_msg2",
      send: "c_arc1_msg2"

    email "c_arc1_msg2",
      replies: ["p_msg2"]

    email "c_msg3",
      replies: ["p_msg3"]

    on_reply "p_msg3",
      do: :complete

    def setup(step) do
    end

    def start(step) do
      e1 = send_email step, "c_msg1"
      step = %{step| meta: %{restarted?: false}}

      {:ok, step, e1, []}
    end

    def complete(step) do
      {:ok, step, []}
    end

    def restart(step, reason, checkpoint) do
      {:ok, %{step| meta: %{restarted?: true}}, %{}, []}
    end

    next_step __MODULE__
  end
end
