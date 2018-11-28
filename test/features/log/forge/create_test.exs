defmodule Helix.Test.Features.Log.Forge.Create do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  import Helix.Test.Macros

  alias Helix.Log.Model.Log
  alias Helix.Log.Query.Log, as: LogQuery
  alias Helix.Process.Model.Process
  alias Helix.Process.Query.Process, as: ProcessQuery

  alias Helix.Test.Log.Helper, as: LogHelper
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  describe "LogForge.Create" do
    test "local life cycle" do
      %{
        local: %{gateway: gateway, entity: entity},
        session: session
      } = SessionSetup.create_local()

      sse_subscribe(session)

      # Prepare request params
      {{req_log_type, req_log_data}, {log_type, log_data}} =
        LogHelper.request_log_info()

      params =
        %{
          "log_type" => req_log_type,
          "log_data" => req_log_data
        }

      prepared_conn =
        conn()
        |> infer_path(:log_forge_create, gateway.server_id)
        |> set_session(session)
        |> put_body(params)

      conn = execute(prepared_conn)

      # Request will fail because user has no LogForger on her system!
      assert_resp_error conn, {:forger, :not_found}

      # Let's create the forger and try again...
      forger = SoftwareSetup.log_forger!(server_id: gateway.server_id)

      conn = execute(prepared_conn)
      request_id = get_request_id(conn)

      # Should have worked
      assert_status conn, 200

      [process_created_event] = wait_events [:process_created]

      assert process_created_event.data.type == "log_forge_create"
      assert process_created_event.meta.request_id == request_id
      assert process_created_event.domain == "server"
      assert process_created_event.domain_id == to_string(gateway.server_id)

      process =
        process_created_event.data.process_id
        |> Process.ID.cast!()
        |> ProcessQuery.fetch()

      # Make sure the process was created correctly
      assert process.type == :log_forge_create
      assert process.data.forger_version == forger.modules.log_create.version
      assert process.data.log_type == log_type
      assert_map_str process.data.log_data, log_data

      assert process.gateway_id == gateway.server_id
      assert process.target_id == gateway.server_id
      assert process.source_entity_id == entity.entity_id
      assert process.src_file_id == forger.file_id

      # local process; no connection info
      refute process.network_id
      refute process.src_connection_id
      refute process.bounce_id

      # Simulate completion of the software
      TOPHelper.force_completion(process)

      [log_created_event, notification_added_event] =
        wait_events [:log_created, :notification_added]

      # Local server receives information about the newly created log
      assert log_created_event.data.type == to_string(log_type)
      assert_map_str log_created_event.data.data, log_data

      # The newly created log is sitting there at the server
      log_id = log_created_event.data.log_id |> Log.ID.cast!()
      log = LogQuery.fetch(log_id)

      assert log.revision_id == 1
      assert log.server_id == gateway.server_id
      assert log.revision.entity_id == entity.entity_id
      assert log.revision.forge_version == forger.modules.log_create.version
      assert log.revision.type == log_type
      assert_map_str log.revision.data, log_data

      # Client received the log notification
      assert notification_added_event.data.class == "server"
      assert notification_added_event.data.code == "log_created"
      assert notification_added_event.data.data.log_id == to_string(log.log_id)

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
      forger = SoftwareSetup.log_forger!(server_id: gateway.server_id)

      params =
        %{
          "log_type" => req_log_type,
          "log_data" => req_log_data
        }

      base_conn =
        conn()
        |> infer_path(:log_forge_create, [endpoint.server_id])
        |> set_session(session)
        |> put_body(params)

      # Let's edit the log!
      conn = execute(base_conn)
      request_id = get_request_id(conn)

      assert_status conn, 200

      [process_created_event] = wait_events [:process_created]

      assert process_created_event.data.type == "log_forge_create"
      assert process_created_event.meta.request_id == request_id
      assert process_created_event.domain == "server"

      process =
        process_created_event.data.process_id
        |> Process.ID.cast!()
        |> ProcessQuery.fetch()

      # Make sure the process was created correctly
      assert process.type == :log_forge_create
      assert process.data.forger_version == forger.modules.log_create.version
      assert process.data.log_type == log_type
      assert_map_str process.data.log_data, log_data

      assert process.gateway_id == gateway.server_id
      assert process.target_id == endpoint.server_id
      assert process.source_entity_id == entity.entity_id
      assert process.src_file_id == forger.file_id

      # remote process; has (some) connection info
      assert process.network_id == @internet_id
      assert process.src_connection_id == context.ssh.connection_id

      # While there may exist a bounce (on the SSH connection), we can safely
      # ignore it, as creating a log won't generate another log, and the bounce
      # information on the process is only used for log generation.
      refute process.bounce_id

      # Simulate completion of the software
      TOPHelper.force_completion(process)

      [log_created_event, notification_added_event] =
        wait_events [:log_created, :notification_added]

      # Local server receives information about the newly created log
      assert log_created_event.data.type == to_string(log_type)
      assert_map_str log_created_event.data.data, log_data

      # The newly created log is sitting there at the server
      log_id = log_created_event.data.log_id |> Log.ID.cast!()
      log = LogQuery.fetch(log_id)

      assert log.revision_id == 1
      assert log.server_id == endpoint.server_id
      assert log.revision.entity_id == entity.entity_id
      assert log.revision.forge_version == forger.modules.log_create.version
      assert log.revision.type == log_type
      assert_map_str log.revision.data, log_data

      # Client received the log notification
      assert notification_added_event.data.class == "server"
      assert notification_added_event.data.code == "log_created"
      assert notification_added_event.data.data.log_id == to_string(log.log_id)

      TOPHelper.top_stop(gateway)
    end
  end
end
