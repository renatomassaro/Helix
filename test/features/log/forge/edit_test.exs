defmodule Helix.Test.Features.Log.Forge.Edit do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  import Helix.Test.Case.ID
  import Helix.Test.Macros

  alias Helix.Log.Query.Log, as: LogQuery
  alias Helix.Process.Model.Process
  alias Helix.Process.Query.Process, as: ProcessQuery

  alias Helix.Test.Log.Helper, as: LogHelper
  alias Helix.Test.Log.Setup, as: LogSetup
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  @internet_id NetworkHelper.internet_id()

  describe "LogForge.Edit" do
    test "local life cycle" do
      %{
        local: %{gateway: gateway, entity: entity},
        session: session
      } = SessionSetup.create_local()

      sse_subscribe(session)

      # Prepare request params
      {{req_log_type, req_log_data}, {log_type, log_data}} =
        LogHelper.request_log_info()

      # Prepare required stuff
      old_log = LogSetup.log!(server_id: gateway.server_id)

      params =
        %{
          "log_type" => req_log_type,
          "log_data" => req_log_data
        }

      base_conn =
        conn()
        |> infer_path(:log_forge_edit, [gateway.server_id, old_log.log_id])
        |> set_session(session)
        |> put_body(params)

      # We'll attempt to edit a log at localhost. This should fail because we do
      # not have a LogForger!
      conn = execute(base_conn)

      assert_resp_error conn, {:forger, :not_found}

      # Let's create the forger and try again...
      forger = SoftwareSetup.log_forger!(server_id: gateway.server_id)

      conn = execute(base_conn)
      request_id = get_request_id(conn)

      # It worked!
      assert_status conn, 200

      [process_created_event] = wait_events [:process_created]

      assert process_created_event.data.type == "log_forge_edit"
      assert process_created_event.meta.request_id == request_id
      assert process_created_event.domain == "server"
      assert process_created_event.domain_id == to_string(gateway.server_id)

      process =
        process_created_event.data.process_id
        |> Process.ID.cast!()
        |> ProcessQuery.fetch()

      # Make sure the process was created correctly
      assert process.type == :log_forge_edit
      assert process.data.forger_version == forger.modules.log_edit.version
      assert process.data.log_type == log_type
      assert_map_str process.data.log_data, log_data

      assert process.gateway_id == gateway.server_id
      assert process.target_id == gateway.server_id
      assert process.source_entity_id == entity.entity_id
      assert process.src_file_id == forger.file_id
      assert process.tgt_log_id == old_log.log_id

      # local process; no connection info
      refute process.network_id
      refute process.src_connection_id
      refute process.bounce_id

      # Simulate completion of the software
      TOPHelper.force_completion(process)

      [log_revised_event, notification_added_event] =
        wait_events [:log_revised, :notification_added]

      assert log_revised_event.meta.process_id == to_string(process.process_id)
      assert log_revised_event.domain == "server"
      assert log_revised_event.domain_id == to_string(gateway.server_id)

      # Local server receives information about the newly revised log
      assert log_revised_event.data.type == to_string(log_type)
      assert_map_str log_revised_event.data.data, log_data

      # The newly revised log is sitting there at the server
      new_log = LogQuery.fetch(old_log.log_id)

      assert new_log.revision_id == 2
      assert new_log.server_id == gateway.server_id
      assert new_log.revision.entity_id == entity.entity_id
      assert new_log.revision.forge_version == forger.modules.log_edit.version
      assert new_log.revision.type == log_type
      assert_map_str new_log.revision.data, log_data

      # Client received the log notification
      assert notification_added_event.data.class == "server"
      assert notification_added_event.data.code == "log_revised"
      assert_id notification_added_event.data.data.log_id, new_log.log_id

      TOPHelper.top_stop(gateway)
    end

    test "remote life cycle" do
      %{
        local: %{gateway: gateway, entity: entity},
        remote: %{endpoint: endpoint},
        session: session,
        context: context
      } = SessionSetup.create_remote()

      sse_subscribe(session)

      # Prepare request params
      {{req_log_type, req_log_data}, {log_type, log_data}} =
        LogHelper.request_log_info()

      # Prepare required stuff
      old_log = LogSetup.log!(server_id: endpoint.server_id)

      params =
        %{
          "log_type" => req_log_type,
          "log_data" => req_log_data
        }

      # We'll try to edit `old_log` at `gateway` (notice the path below).
      conn =
        conn()
        |> infer_path(:log_forge_edit, [gateway.server_id, old_log.log_id])
        |> set_session(session)
        |> put_body(params)
        |> execute()

      # This should fail, as `old_log` exists on `endpoint`, not `gateway`
      assert_resp_error conn, {:log, :not_belongs}

      # Fixing the path. From now on we'll try to edit the log at `endpoint`
      base_conn =
        conn()
        |> infer_path(:log_forge_edit, [endpoint.server_id, old_log.log_id])
        |> set_session(session)
        |> put_body(params)

      # Let's edit the log!
      conn = execute(base_conn)

      # Oops. We do not have a LogForger.
      assert_resp_error conn, {:forger, :not_found}

      # Let's create the forger and try again...
      forger = SoftwareSetup.log_forger!(server_id: gateway.server_id)

      conn = execute(base_conn)
      request_id = get_request_id(conn)

      # It worked!
      [process_created_event] = wait_events [:process_created]

      assert process_created_event.data.type == "log_forge_edit"
      assert process_created_event.meta.request_id == request_id
      assert process_created_event.domain == "server"

      process =
        process_created_event.data.process_id
        |> Process.ID.cast!()
        |> ProcessQuery.fetch()

      # Make sure the process was created correctly
      assert process.type == :log_forge_edit
      assert process.data.forger_version == forger.modules.log_edit.version
      assert process.data.log_type == log_type
      assert_map_str process.data.log_data, log_data

      assert process.gateway_id == gateway.server_id
      assert process.target_id == endpoint.server_id
      assert process.source_entity_id == entity.entity_id
      assert process.src_file_id == forger.file_id
      assert process.tgt_log_id == old_log.log_id

      # local process; no connection info
      assert process.network_id == @internet_id
      assert process.src_connection_id == context.ssh.connection_id

      # See remark on test `LogForge.create (remote)`
      refute process.bounce_id

      # Simulate completion of the software
      TOPHelper.force_completion(process)

      [log_revised_event, notification_added_event] =
        wait_events [:log_revised, :notification_added]

      # Local server receives information about the newly revised log
      assert log_revised_event.data.type == to_string(log_type)
      assert_map_str log_revised_event.data.data, log_data

      # The newly revised log is sitting there at the server
      new_log = LogQuery.fetch(old_log.log_id)

      assert new_log.revision_id == 2
      assert new_log.server_id == endpoint.server_id
      assert new_log.revision.entity_id == entity.entity_id
      assert new_log.revision.forge_version == forger.modules.log_edit.version
      assert new_log.revision.type == log_type
      assert_map_str new_log.revision.data, log_data

      # Client received the log notification
      assert notification_added_event.data.class == "server"
      assert notification_added_event.data.code == "log_revised"
      assert_id notification_added_event.data.data.log_id, new_log.log_id

      TOPHelper.top_stop(gateway)
    end
  end
end
