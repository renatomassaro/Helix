defmodule Helix.Test.Features.Storyline.Restart do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  alias Helix.Test.Story.Helper, as: StoryHelper
  alias Helix.Test.Story.Vars, as: StoryVars

  @moduletag :feature

  describe "restart" do
    test "user-requested restart" do
      %{
        local: %{entity: entity},
        session: session
      } = SessionSetup.create_local()

      params = %{"contact_id" => "friend"}
      s = StoryVars.vars()

      base_conn =
        conn()
        |> infer_path(:story_restart, [])
        |> set_session(session)
        |> put_body(params)

      conn = execute(base_conn)

      # Restart attemp will fail, for we are on the very first message (which
      # is a checkpoint)
      assert_resp_error conn, :already_checkpoint, 403

      # Let's reply to the first message...
      [story_step] = StoryHelper.get_steps_from_entity(entity.entity_id)
      StoryHelper.reply(story_step)

      [before_story_step] = StoryHelper.get_steps_from_entity(entity.entity_id)

      # And attempt a restart
      conn = execute(base_conn)

      # Now it worked!
      assert_status conn, 200

      [after_story_step] = StoryHelper.get_steps_from_entity(entity.entity_id)

      # Previous messages were deleted
      assert length(before_story_step.emails_sent) == 3
      assert length(after_story_step.emails_sent) == 1
      assert after_story_step.allowed_replies == [s.tutorial.welcome.msg2]

      # NOTE: TODO: There's a bug here. See StoryFlow.restart for more details.
      # :timer.sleep(7000)
      # [afaf_story_step] = StoryHelper.get_steps_from_entity(entity.entity_id)
      # IO.inspect(afaf_story_step)
      # IO.inspect(after_story_step)
    end

    # test "flow" do
    #   {server_socket, %{account: account}} =
    #     ChannelSetup.join_storyline_server()

    #   entity = EntityHelper.fetch_entity_from_account(account)
    #   entity_id = entity.entity_id

    #   # Subscribe for events
    #   ChannelSetup.join_account(
    #     account_id: account.account_id, socket: server_socket
    #   )

    #   # Player is on mission
    #   [%{entry: story_step}] = StoryQuery.get_steps(entity_id)

    #   # Magically proceed to the next step (DownloadCracker) by replying to the
    #   # first one (SetupPC) twice
    #   StoryHelper.reply(story_step)
    #   StoryHelper.reply(story_step)

    #   [%{entry: story_step, object: step}] = StoryQuery.get_steps(entity_id)

    #   # We are on DownloadCracker
    #   assert step.name == :tutorial@download_cracker

    #   # We've the email received `download_cracker1`
    #   assert story_step.emails_sent == ["download_cracker1"]

    #   # 5 emails: 2e + 2r from prev step + "download_cracker1"
    #   story_email = StoryQuery.fetch_email(entity_id, step.contact)
    #   assert length(story_email.emails) == 5
    #   [_, _, _, _, email] = story_email.emails

    #   assert email.meta["ip"] == step.meta.ip

    #   # Now we'll be nasty and delete the cracker...
    #   step.meta.cracker_id
    #   |> FileInternal.fetch()
    #   |> FileInternal.delete()

    #   # And publish to the user...
    #   step.meta.cracker_id
    #   |> EventSetup.Software.file_deleted(step.meta.server_id)
    #   |> EventHelper.emit()

    #   [story_step_restarted] = wait_events [:story_step_restarted]

    #   # The client received the publication about the new step
    #   assert story_step_restarted.data.reason == "file_deleted"
    #   assert story_step_restarted.data.checkpoint == "download_cracker1"
    #   assert story_step_restarted.data.step == to_string(step.name)
    #   assert story_step_restarted.data.meta.ip == step.meta.ip
    #   assert story_step_restarted.data.allowed_replies

    #   # By querying directly on the DB, the data has been updated as well
    #   [%{object: new_step}] = StoryQuery.get_steps(entity_id)

    #   # `cracker_id` has changed (it was regenerated)
    #   refute new_step.meta.cracker_id == step.meta.cracker_id

    #   # But the unchanged data is the same
    #   assert new_step.meta.server_id == step.meta.server_id
    #   assert new_step.meta.ip == step.meta.ip

    #   # Still 5 emails...
    #   story_email = StoryQuery.fetch_email(entity_id, step.contact)
    #   assert length(story_email.emails) == 5
    #   [_, _, _, _, new_email] = story_email.emails

    #   assert new_email.meta["ip"] == step.meta.ip

    #   # even though both `email` and `new_email` have the same meta and ID,
    #   # they are not the same (different timestamps)
    #   refute new_email == email
    # end
  end
end
