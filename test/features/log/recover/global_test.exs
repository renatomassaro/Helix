defmodule Helix.Test.Features.Log.Recover.Global do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  alias Helix.Log.Query.Log, as: LogQuery
  alias Helix.Process.Model.Process
  alias Helix.Process.Query.Process, as: ProcessQuery

  alias Helix.Test.Log.Setup, as: LogSetup
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  import Helix.Test.Macros

  describe "LogRecover.Global" do
    test "local life cycle (natural log)" do
      %{
        local: %{gateway: gateway, entity: entity},
        session: session
      } = SessionSetup.create_local()

      sse_subscribe(session)

      # Logs that will be worked on (one of them is recoverable)
      LogSetup.log!(server_id: gateway.server_id)
      log = LogSetup.log!(server_id: gateway.server_id, revisions: 2)

      base_conn =
        conn()
        |> infer_path(:log_recover_global, gateway.server_id)
        |> set_session(session)

      # We'll attempt to recover a log at localhost. This should fail because we
      # do not have a LogRecover!
      conn = execute(base_conn)

      assert_resp_error conn, {:recover, :not_found}

      # Let's create the recover and try again...
      recover = SoftwareSetup.log_recover!(server_id: gateway.server_id)

      # It worked!
      conn = execute(base_conn)
      request_id = get_request_id(conn)

      assert_status conn, 200

      [process_created_event] = wait_events [:process_created]

      assert process_created_event.data.type == "log_recover_global"
      assert process_created_event.meta.request_id == request_id
      assert process_created_event.domain == "server"
      assert process_created_event.domain_id == to_string(gateway.server_id)

      process =
        process_created_event.data.process_id
        |> Process.ID.cast!()
        |> ProcessQuery.fetch()

      # Make sure the process was created correctly
      assert process.type == :log_recover_global
      assert process.data.recover_version == recover.modules.log_recover.version
      assert process.tgt_log_id == log.log_id

      assert process.gateway_id == gateway.server_id
      assert process.target_id == gateway.server_id
      assert process.source_entity_id == entity.entity_id
      assert process.src_file_id == recover.file_id

      # local process; no connection info
      refute process.network_id
      refute process.src_connection_id
      refute process.bounce_id

      # Simulate completion of the software
      TOPHelper.force_completion(process)

      [log_recovered_event, notification_added_event] =
        wait_events [:log_recovered, :notification_added]

      [original_revision, _fake_revision] = LogQuery.fetch_revisions(log)

      # Local server receives information about the newly recovered log
      assert log_recovered_event.data.type == to_string(original_revision.type)
      assert_map_str log_recovered_event.data.data, original_revision.data

      # The recently recovered log has changed its last revision
      new_log = LogQuery.fetch(log.log_id)

      assert new_log.revision_id == 1
      assert new_log.server_id == gateway.server_id
      assert new_log.revision.type == original_revision.type
      assert_map_str new_log.revision.data, original_revision.data

      # Client received the log notification
      assert notification_added_event.data.class == "server"
      assert notification_added_event.data.code == "log_recovered"
      assert notification_added_event.data.data.log_id == to_string(log.log_id)

      # LogRecoverProcess is recursive, so it should still be working.
      new_process = ProcessQuery.fetch(process.process_id)

      # It's not working on any log, as there aren't any recoverable logs now
      refute new_process.tgt_log_id

      TOPHelper.top_stop(gateway)
    end

    test "remote life cycle (artificial log)" do
      %{
        local: %{gateway: gateway, entity: entity},
        remote: %{endpoint: endpoint},
        session: session,
        context: context
      } = SessionSetup.create_remote()

      sse_subscribe(session)

      # Artificial log that will be worked on. Note it has multiple revisions
      log =
        LogSetup.log!(
          server_id: endpoint.server_id, forge_version: 50, revisions: 2
        )

      # Add required LogRecover software to `gateway`
      recover = SoftwareSetup.log_recover!(server_id: gateway.server_id)

      base_conn =
        conn()
        |> infer_path(:log_recover_global, endpoint.server_id)
        |> set_session(session)

      # It worked!
      conn = execute(base_conn)
      request_id = get_request_id(conn)

      assert_status conn, 200

      [process_created_event] = wait_events [:process_created]

      assert process_created_event.data.type == "log_recover_global"
      assert process_created_event.meta.request_id == request_id
      assert process_created_event.domain == "server"

      process =
        process_created_event.data.process_id
        |> Process.ID.cast!()
        |> ProcessQuery.fetch()

      # Make sure the process was created correctly
      assert process.type == :log_recover_global
      assert process.data.recover_version == recover.modules.log_recover.version
      assert process.tgt_log_id == log.log_id

      assert process.gateway_id == gateway.server_id
      assert process.target_id == endpoint.server_id
      assert process.source_entity_id == entity.entity_id
      assert process.src_file_id == recover.file_id

      # local process; no connection info
      assert process.network_id == @internet_id
      assert process.src_connection_id == context.ssh.connection_id

      # Simulate completion of the software
      TOPHelper.force_completion(process)

      [log_recovered_event, notification_added_event] =
        wait_events [:log_recovered, :notification_added]

      [original_revision, _fake_revision] = LogQuery.fetch_revisions(log)

      # Local server receives information about the newly recovered log
      assert log_recovered_event.data.type == to_string(original_revision.type)
      assert_map_str log_recovered_event.data.data, original_revision.data

      # The recently recovered log has changed its last revision
      new_log = LogQuery.fetch(log.log_id)

      assert new_log.revision_id == 1
      assert new_log.server_id == endpoint.server_id
      assert new_log.revision.type == original_revision.type
      assert_map_str new_log.revision.data, original_revision.data

      # Client received the log notification
      assert notification_added_event.data.class == "server"
      assert notification_added_event.data.code == "log_recovered"
      assert notification_added_event.data.data.log_id == to_string(log.log_id)

      # LogRecoverProcess is recursive, so it should still be working.
      new_process = ProcessQuery.fetch(process.process_id)

      # It IS working on a log - the same one as before. The artificial log was
      # NOT destroyed - because there still is one revision left.
      assert new_process.tgt_log_id == log.log_id

      TOPHelper.top_stop(gateway)
    end
  end
end
