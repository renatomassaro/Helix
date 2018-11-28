defmodule Helix.Log.Request.Recover.GlobalTest do

  use Helix.Test.Case.Integration

  alias Helix.Log.Request.Recover.Global, as: GlobalRecoverRequest
  alias Helix.Process.Query.Process, as: ProcessQuery

  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper

  describe "check_permissions/2" do
    test "accepts when everything is OK" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_local, with_gateway: true)

      recover = SoftwareSetup.log_recover!(server_id: gateway.server_id)

      request = RequestHelper.mock_request()

      assert {:ok, request} =
        RequestHelper.check_permissions(GlobalRecoverRequest, request, session)

      assert request.meta.recover == recover
      assert request.meta.gateway == gateway
    end

    test "rejects when player does not have a recover" do
      {session, %{endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      request = RequestHelper.mock_request()

      assert {:error, _, reason} =
        RequestHelper.check_permissions(GlobalRecoverRequest, request, session)
      assert reason == {:recover, :not_found}

      # Let's try again, but now we'll create a LogRecover at the TARGET.
      # The player may only use software from his gateway, so this should fail

      SoftwareSetup.log_recover!(server_id: endpoint.server_id)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(GlobalRecoverRequest, request, session)
      assert reason == {:recover, :not_found}
    end
  end

  describe "handle_request/2" do
    test "starts the process (local)" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_local, with_gateway: true)

      recover = SoftwareSetup.log_recover!(server_id: gateway.server_id)

      request = RequestHelper.mock_request()

      assert {:ok, _request} =
        RequestHelper.handle_request(GlobalRecoverRequest, request, session)

      assert [process] = ProcessQuery.get_processes_on_server(gateway.server_id)

      assert process.type == :log_recover_global
      assert process.gateway_id == process.target_id
      assert process.src_file_id == recover.file_id
      refute process.src_connection_id
      assert process.data.recover_version == recover.modules.log_recover.version

      # No log being recovered because there are no recoverable logs on server
      refute process.tgt_log_id

      TOPHelper.top_stop(gateway)
    end

    test "starts the process (remote)" do
      {session, %{gateway: gateway, endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      recover = SoftwareSetup.log_recover!(server_id: gateway.server_id)

      request = RequestHelper.mock_request()

      assert {:ok, _request} =
        RequestHelper.handle_request(GlobalRecoverRequest, request, session)

      assert [process] = ProcessQuery.get_processes_on_server(gateway.server_id)

      assert process.type == :log_recover_global
      assert process.gateway_id == gateway.server_id
      assert process.target_id == endpoint.server_id
      assert process.src_file_id == recover.file_id
      assert process.src_connection_id == session.context.ssh.connection_id
      assert process.data.recover_version == recover.modules.log_recover.version

      # No log being recovered because there are no recoverable logs on server
      refute process.tgt_log_id

      TOPHelper.top_stop(gateway)
    end
  end
end
