defmodule Helix.Software.Request.Cracker.BruteforceTest do

  use Helix.Test.Case.Integration

  alias Helix.Cache.Query.Cache, as: CacheQuery
  alias Helix.Process.Query.Process, as: ProcessQuery
  alias Helix.Software.Request.Cracker.Bruteforce, as: CrackerBruteforceRequest

  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Network.Setup, as: NetworkSetup
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  @session SessionHelper.mock_session!(:server_local)
  @internet_id NetworkHelper.internet_id()
  @internet_id_str to_string(@internet_id)

  describe "check_params/2" do
    test "validates and casts expected data" do
      network_id = NetworkHelper.id()
      ip = NetworkHelper.ip()

      params =
        %{
          "target_nip" => build_target_nip(network_id, ip),
          "bounce_id" => nil
        }

      request = RequestHelper.mock_request(unsafe: params)
      assert {:ok, request} =
        CrackerBruteforceRequest.check_params(request, @session)

      assert request.params.network_id == network_id
      assert request.params.ip == ip
      refute request.params.bounce_id
    end

    test "rejects when session access context is remote" do
      network_id = NetworkHelper.id()
      ip = NetworkHelper.ip()

      params =
        %{
          "target_nip" => build_target_nip(network_id, ip),
          "bounce_id" => nil
        }

      remote_session = SessionHelper.mock_session!(:server_remote)

      request = RequestHelper.mock_request(unsafe: params)
      assert {:error, _, reason} =
        CrackerBruteforceRequest.check_params(request, remote_session)

      assert reason == :bad_attack_src
    end
  end

  describe "check_permissions/2" do
    test "accepts when everything is OK" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_local, with_gateway: true)

      target = ServerSetup.server!()
      {:ok, [tgt_nip]} =
        CacheQuery.from_server_get_nips(target.server_id)

      bounce = NetworkSetup.Bounce.bounce!(entity_id: session.entity_id)

      # Cracker is required!
      cracker =
        SoftwareSetup.cracker!(server_id: session.context.gateway.server_id)

      params =
        %{
          "target_nip" => build_target_nip(tgt_nip.network_id, tgt_nip.ip),
          "bounce_id" => to_string(bounce.bounce_id)
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, request} =
        RequestHelper.check_permissions(
          CrackerBruteforceRequest, request, session
        )

      assert request.meta.bounce == bounce
      assert request.meta.cracker == cracker
      assert request.meta.gateway == gateway
      assert request.meta.target == target
    end

    test "rejects when target does not exist" do
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      # Random target
      network_id = NetworkHelper.id()
      ip = NetworkHelper.ip()

      params =
        %{
          "target_nip" => build_target_nip(network_id, ip),
          "bounce_id" => nil
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(
          CrackerBruteforceRequest, request, session
        )
      assert reason == {:nip, :not_found}
    end

    test "rejects when player does not have a valid cracker" do
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      target = ServerSetup.server!()
      {:ok, [tgt_nip]} =
        CacheQuery.from_server_get_nips(target.server_id)

      params =
        %{
          "target_nip" => build_target_nip(tgt_nip.network_id, tgt_nip.ip),
          "bounce_id" => nil
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(
          CrackerBruteforceRequest, request, session
        )

      assert reason == {:cracker, :not_found}
    end

    test "rejects when bounce is invalid" do
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      bounce = NetworkSetup.Bounce.bounce!()

      # For this test, it doesn't matter if the target does not exist
      network_id = NetworkHelper.id()
      ip = NetworkHelper.ip()

      params =
        %{
          "target_nip" => build_target_nip(network_id, ip),
          "bounce_id" => to_string(bounce.bounce_id)
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(
          CrackerBruteforceRequest, request, session
        )

      assert reason == {:bounce, :not_belongs}
    end
  end

  describe "handle_request" do
    test "bruteforce process is started" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_local, with_gateway: true)

      target = ServerSetup.server!()
      {:ok, [tgt_nip]} =
        CacheQuery.from_server_get_nips(target.server_id)

      bounce = NetworkSetup.Bounce.bounce!(entity_id: session.entity_id)

      # Cracker is required!
      cracker =
        SoftwareSetup.cracker!(server_id: session.context.gateway.server_id)

      params =
        %{
          "target_nip" => build_target_nip(tgt_nip.network_id, tgt_nip.ip),
          "bounce_id" => to_string(bounce.bounce_id)
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, _request} =
        RequestHelper.handle_request(CrackerBruteforceRequest, request, session)

      # Process was created
      assert [process] = ProcessQuery.get_processes_on_server(gateway.server_id)

      # And it contains the expected fields
      assert process.type == :cracker_bruteforce
      assert process.source_entity_id == session.entity_id
      assert process.target_id == target.server_id
      assert process.bounce_id == bounce.bounce_id
      assert process.src_file_id == cracker.file_id
      assert process.network_id == tgt_nip.network_id
      assert process.data.target_server_ip == tgt_nip.ip
    end
  end

  defp build_target_nip(@internet_id, ip),
    do: ip <> "$*"
  defp build_target_nip(network_id, ip),
    do: ip <> "$" <> String.replace(to_string(network_id), ":", ",")
end
