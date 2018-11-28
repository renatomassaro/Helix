defmodule Helix.Log.Request.Forge.CreateTest do

  use Helix.Test.Case.Integration

  import Helix.Test.Macros

  alias Helix.Log.Request.Forge.Create, as: ForgeCreateRequest
  alias Helix.Process.Query.Process, as: ProcessQuery

  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Log.Helper, as: LogHelper

  @session SessionHelper.mock_session!(:server_local)

  describe "check_params/2" do
    test "validates expected data" do
      {{req_log_type, req_log_data}, log_info} = LogHelper.request_log_info()

      params = %{
        "log_type" => req_log_type,
        "log_data" => req_log_data
      }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, request} = ForgeCreateRequest.check_params(request, @session)

      assert request.params.log_info == log_info
    end

    test "rejects when log_info is invalid" do
      p0 =
        %{
          "log_type" => "invalid_type",
          "log_data" => %{}
        }
      p1 =
        %{
          "log_type" => "error",
          "log_data" => "string"
        }

      # missing entries
      p2 =
        %{
          "log_type" => "connection_bounced",
          "log_data" => %{"ip_prev" => "1.2.3.4", "network_id" => "::"}
        }

      # invalid data type
      p3 =
        %{
          "log_type" => "connection_bounced",
          "log_data" => nil
        }

      # missing `log_data`
      p4 =
        %{
          "log_type" => "connection_bounced",
        }

      r0 = RequestHelper.mock_request(unsafe: p0)
      r1 = RequestHelper.mock_request(unsafe: p1)
      r2 = RequestHelper.mock_request(unsafe: p2)
      r3 = RequestHelper.mock_request(unsafe: p3)
      r4 = RequestHelper.mock_request(unsafe: p4)

      assert {:error, _, err0} = ForgeCreateRequest.check_params(r0, @session)
      assert {:error, _, err1} = ForgeCreateRequest.check_params(r1, @session)
      assert {:error, _, err2} = ForgeCreateRequest.check_params(r2, @session)
      assert {:error, _, err3} = ForgeCreateRequest.check_params(r3, @session)
      assert {:error, _, err4} = ForgeCreateRequest.check_params(r4, @session)

      assert err0 == :bad_log_type
      assert err0 == err1

      assert err2 == :bad_log_data
      assert err3 == err2
      assert err4 == err3
    end
  end

  describe "check_permissions/2" do
    test "accepts when everything is OK" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_local, with_gateway: true)

      forger = SoftwareSetup.log_forger!(server_id: gateway.server_id)
      {req_log_type, req_log_data} = LogHelper.request_log_info!()

      params =
        %{
          "log_type" => req_log_type,
          "log_data" => req_log_data
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, request} =
        RequestHelper.check_permissions(ForgeCreateRequest, request, session)

      assert request.meta.forger == forger
      assert request.meta.gateway == gateway
    end

    test "rejects when player does not have a forger" do
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      {req_log_type, req_log_data} = LogHelper.request_log_info!()

      params =
        %{
          "log_type" => req_log_type,
          "log_data" => req_log_data
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:error, _request, reason} =
        RequestHelper.check_permissions(ForgeCreateRequest, request, session)

      assert reason == {:forger, :not_found}
    end
  end

  describe "handle_request/2" do
    test "starts the process (local)" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_local, with_gateway: true)

      forger = SoftwareSetup.log_forger!(server_id: gateway.server_id)
      {{req_log_type, req_log_data}, {log_type, log_data}} =
        LogHelper.request_log_info()

      params =
        %{
          "log_type" => req_log_type,
          "log_data" => req_log_data
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, _request} =
        RequestHelper.handle_request(ForgeCreateRequest, request, session)

      assert [process] = ProcessQuery.get_processes_on_server(gateway.server_id)

      assert process.type == :log_forge_create
      assert process.gateway_id == process.target_id
      assert process.src_file_id == forger.file_id
      refute process.src_connection_id
      assert process.data.forger_version == forger.modules.log_create.version
      assert process.data.log_type == log_type
      assert_map_str process.data.log_data, Map.from_struct(log_data)

      TOPHelper.top_stop(gateway)
    end

    test "starts the process (remote)" do
      {session, %{gateway: gateway, endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      forger = SoftwareSetup.log_forger!(server_id: gateway.server_id)
      {{req_log_type, req_log_data}, {log_type, log_data}} =
        LogHelper.request_log_info()

      params =
        %{
          "log_type" => req_log_type,
          "log_data" => req_log_data
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, _request} =
        RequestHelper.handle_request(ForgeCreateRequest, request, session)

      assert [process] = ProcessQuery.get_processes_on_server(gateway.server_id)

      assert process.type == :log_forge_create
      assert process.gateway_id == gateway.server_id
      assert process.target_id == endpoint.server_id
      assert process.src_file_id == forger.file_id
      assert process.src_connection_id == session.context.ssh.connection_id
      assert process.data.forger_version == forger.modules.log_create.version
      assert process.data.log_type == log_type
      assert_map_str process.data.log_data, Map.from_struct(log_data)

      TOPHelper.top_stop(gateway)
    end
  end
end
