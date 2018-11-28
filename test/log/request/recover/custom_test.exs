defmodule Helix.Log.Request.Recover.CustomTest do

  use Helix.Test.Case.Integration

  alias Helix.Log.Request.Recover.Custom, as: CustomRecoverRequest
  alias Helix.Process.Query.Process, as: ProcessQuery

  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Log.Helper, as: LogHelper
  alias Helix.Test.Log.Setup, as: LogSetup

  @session SessionHelper.mock_session(:server_local)

  describe "check_params/2" do
    test "validates expected data" do
      log_id = LogHelper.id()
      url_params = %{"log_id" => to_string(log_id)}

      request = RequestHelper.mock_request(url_params: url_params)

      assert {:ok, request} =
        RequestHelper.check_params(CustomRecoverRequest, request, @session)

      assert request.params.log_id == log_id
    end

    test "rejects when `log_id` is missing or invalid" do
      url_params = %{"log_id" => "b0gus_value"}

      request = RequestHelper.mock_request(url_params: url_params)

      assert {:error, _, reason} =
        RequestHelper.check_params(CustomRecoverRequest, request, @session)

      assert reason == :bad_request
    end
  end

  describe "check_permissions/2" do
    test "accepts when everything is OK" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_local, with_gateway: true)

      recover = SoftwareSetup.log_recover!(server_id: gateway.server_id)
      log = LogSetup.log!(server_id: gateway.server_id)

      url_params = %{"log_id" => to_string(log.log_id)}

      request = RequestHelper.mock_request(url_params: url_params)

      assert {:ok, request} =
        RequestHelper.check_permissions(CustomRecoverRequest, request, session)

      assert request.meta.recover == recover
      assert request.meta.gateway == gateway
      assert request.meta.log.log_id == log.log_id
      assert request.meta.log.server_id == gateway.server_id
    end

    test "rejects when player does not have a recover" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_local, with_gateway: true)

      log = LogSetup.log!(server_id: gateway.server_id)
      url_params = %{"log_id" => to_string(log.log_id)}

      request = RequestHelper.mock_request(url_params: url_params)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(CustomRecoverRequest, request, session)
      assert reason == {:recover, :not_found}
    end
  end

  describe "handle_request/2" do
    test "starts the process (local)" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_local, with_gateway: true)

      recover = SoftwareSetup.log_recover!(server_id: gateway.server_id)

      log = LogSetup.log!(server_id: gateway.server_id)
      url_params = %{"log_id" => to_string(log.log_id)}

      request = RequestHelper.mock_request(url_params: url_params)

      assert {:ok, _request} =
        RequestHelper.handle_request(CustomRecoverRequest, request, session)

      assert [process] = ProcessQuery.get_processes_on_server(gateway.server_id)

      assert process.type == :log_recover_custom
      assert process.gateway_id == process.target_id
      assert process.src_file_id == recover.file_id
      refute process.src_connection_id
      assert process.data.recover_version == recover.modules.log_recover.version

      # As expected, the `log_id` on `url_params` is being recovered
      assert process.tgt_log_id == log.log_id

      TOPHelper.top_stop(gateway)
    end

    test "starts the process (remote)" do
      {session, %{gateway: gateway, endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      recover = SoftwareSetup.log_recover!(server_id: gateway.server_id)

      log = LogSetup.log!(server_id: endpoint.server_id)
      url_params = %{"log_id" => to_string(log.log_id)}

      request = RequestHelper.mock_request(url_params: url_params)

      assert {:ok, _request} =
        RequestHelper.handle_request(CustomRecoverRequest, request, session)

      assert [process] = ProcessQuery.get_processes_on_server(gateway.server_id)

      assert process.type == :log_recover_custom
      assert process.gateway_id == gateway.server_id
      assert process.target_id == endpoint.server_id
      assert process.src_file_id == recover.file_id
      assert process.src_connection_id == session.context.ssh.connection_id
      assert process.data.recover_version == recover.modules.log_recover.version

      # As expected, the `log_id` on `url_params` is being recovered
      assert process.tgt_log_id == log.log_id

      TOPHelper.top_stop(gateway)
    end
  end
end
