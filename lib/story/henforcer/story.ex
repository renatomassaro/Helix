defmodule Helix.Story.Henforcer.Story do

  import Helix.Henforcer

  alias Helix.Entity.Model.Entity
  alias Helix.Story.Model.Step
  alias Helix.Story.Model.Steppable
  alias Helix.Story.Model.Story.Step
  alias Helix.Story.Query.Story, as: StoryQuery

  @type step_exists_relay :: %{step: Step.t, story_step: Story.Step.t}
  @type step_exists_relay_partial :: %{}
  @type step_exists_error ::
    {false, {:step, :not_found}, step_exists_relay_partial}

  @spec step_exists?(Entity.id, Step.contact_id) ::
    {true, step_exists_relay}
    | step_exists_error
  def step_exists?(entity_id, contact_id) do
    with \
      %{object: step, entry: story_step} <-
        StoryQuery.fetch_step(entity_id, contact_id)
    do
      reply_ok(%{step: step, story_step: story_step})
    else
      _ ->
        reply_error({:step, :not_found})
    end
  end

  @type can_restart_relay ::
    %{step: Step.t, story_step: Story.Step.t, checkpoint: Step.checkpoint}
  @type can_restart_relay_partial :: %{step: Step.t, story_step: Story.Step.t}
  @type can_restart_error ::
    {false, {:already, :checkpoint}, can_restart_relay_partial}
    | {false, {:checkpoint, :not_found}, can_restart_relay_partial}
    | step_exists_error

  @spec can_restart?(Entity.id, Step.contact_id) ::
    {true, can_restart_relay}
    | can_restart_error
  def can_restart?(entity_id, contact_id) do
    with \
      {true, r1} <- step_exists?(entity_id, contact_id),
      step = r1.step,
      story_step = r1.story_step,
      last_message_id = List.last(story_step.emails_sent),
      {true, checkpoint = {checkpoint_id, _}} <-
        Steppable.checkpoint_find(step, last_message_id),
      true <- last_message_id != checkpoint_id || :already_checkpoint
    do
      reply_ok(relay(r1, %{checkpoint: checkpoint}))
    else
      :already_checkpoint ->
        reply_error({:already, :checkpoint})

      false ->
        reply_error({:checkpoint, :not_found})

      error ->
        error
    end
  end
end
