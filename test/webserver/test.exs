defmodule Helix.Webserver.Test do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  import Helix.Test.Case.ID
  import Helix.Test.Macros

  alias Helix.Log.Model.Log
  alias Helix.Log.Query.Log, as: LogQuery
  alias Helix.Process.Model.Process
  alias Helix.Process.Query.Process, as: ProcessQuery

  alias Helix.Test.Account.Setup, as: AccountSetup
  alias Helix.Test.Log.Helper, as: LogHelper
  alias Helix.Test.Log.Setup, as: LogSetup
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  @internet_id NetworkHelper.internet_id()
  # @endpoint Helix.Webserver.Endpoint

  describe "test" do
    test "forges log (create)" do
      %{local: %{account: account, gateway: gateway}, session: session} =
        SessionSetup.create_local()

      sse_subscribe(session)

      # Prepare request params
      log_info = {log_type, log_data} = LogHelper.log_info()
      {req_log_type, req_log_data} = request_log_info(log_info)
      # request_id = RequestHelper.id()

      params =
        %{
          "action" => "create",
          "log_type" => req_log_type,
          "log_data" => req_log_data,
          # "request_id" => request_id
        }

      prepared_conn =
        conn()
        |> infer_path(:log_forge_create, gateway.server_id)
        |> set_session(session)
        |> put_body(params)

      conn = execute(prepared_conn)

      # Request will fail because user has no LogForger on her system!
      assert_resp_error conn, {:forger, :not_found}
      assert_status conn, 403

      # Let's create the forger and try again...
      forger = SoftwareSetup.log_forger!(server_id: gateway.server_id)

      conn = execute(prepared_conn)

      # Should have worked
      assert_status conn, 200

      [process_created_event] = wait_events [:process_created]

      assert process_created_event.data.type == "log_forge_create"
      # assert process_created_event.meta.request_id == request_id

      process =
        process_created_event.data.process_id
        |> Process.ID.cast!()
        |> ProcessQuery.fetch()

      # Make sure the process was created correctly
      assert process.type == :log_forge_create
      assert process.data.forger_version == forger.modules.log_create.version
      assert process.data.log_type == log_type
      # assert_map_str process.data.log_data, log_data

      assert process.gateway_id == gateway.server_id
      assert process.target_id == gateway.server_id
      # assert process.source_entity_id == entity.entity_id
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
      # assert log.revision.entity_id == entity.entity_id
      assert log.revision.forge_version == forger.modules.log_create.version
      assert log.revision.type == log_type
      assert_map_str log.revision.data, log_data

      # Client received the log notification
      assert notification_added_event.data.class == "server"
      assert notification_added_event.data.code == "log_created"
      assert notification_added_event.data.data.log_id == to_string(log.log_id)

      TOPHelper.top_stop(gateway)
    end

    test "LogForge.Edit life cycle (remote)" do
      %{
        local: %{account: account, gateway: gateway, entity: entity},
        remote: %{endpoint: endpoint},
        session: session,
        context: context
      } = SessionSetup.create_remote()

      sse_subscribe(session)

      # Prepare request params
      log_info = {log_type, log_data} = LogHelper.log_info()
      {req_log_type, req_log_data} = request_log_info(log_info)
      # request_id = RequestHelper.id()

      # Prepare required stuff
      old_log = LogSetup.log!(server_id: endpoint.server_id)

      params =
        %{
          "action" => "edit",
          "log_type" => req_log_type,
          "log_data" => req_log_data
          # "request_id" => request_id
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

      # It worked!
      [process_created_event] = wait_events [:process_created]

      assert process_created_event.data.type == "log_forge_edit"
      # assert process_created_event.meta.request_id == request_id

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

    defp request_log_info({log_type, log_data}) do
      # Phoenix input has this format: %{"map" => "string"}
      stringified_log_data =
        log_data
        |> Map.from_struct()
        |> Enum.reduce([], fn {k, v}, acc ->
          [{to_string(k), to_string(v)} | acc]
        end)
        |> Enum.into(%{})

      {to_string(log_type), stringified_log_data}
    end
  end
end
