defmodule Helix.Software.Request.PFTP.File.DownloadTest do

  use Helix.Test.Case.Integration

  alias Helix.Cache.Query.Cache, as: CacheQuery
  alias Helix.Process.Query.Process, as: ProcessQuery
  alias Helix.Software.Request.PFTP.File.Download, as: PFTPFileDownloadRequest

  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Software.Helper, as: SoftwareHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  describe "check_params/2" do
    test "requires a valid nip" do
      session = SessionHelper.mock_session!(:server_remote)

      p1 = %{
        "file_id" => "::f",
        "endpoint_nip" => "InvalidNip$*",
        "storage_id" => "::a"
      }

      p2 = %{
        "file_id" => "Im not a file",
        "endpoint_nip" => "1.2.3.4$*",
        "storage_id" => "::a"
      }

      p3 = %{
        "file_id" => "::f",
        "endpoint_nip" => "1.2.3.4$am not an id",
        "storage_id" => "::a"
      }

      valid = %{
        "file_id" => "::f",
        "endpoint_nip" => "1.2.3.4$*",
        "storage_id" => "::a"
      }

      r1 = RequestHelper.mock_request(unsafe: p1)
      r2 = RequestHelper.mock_request(unsafe: p2)
      r3 = RequestHelper.mock_request(unsafe: p3)

      assert {:error, _, e1} = PFTPFileDownloadRequest.check_params(r1, session)
      assert {:error, _, e2} = PFTPFileDownloadRequest.check_params(r2, session)
      assert {:error, _, e3} = PFTPFileDownloadRequest.check_params(r3, session)

      # This is how you remind me of what I really am
      assert e1 == :bad_request
      assert e2 == :bad_request
      assert e3 == :bad_request

      req = RequestHelper.mock_request(unsafe: valid)
      assert {:ok, request} = PFTPFileDownloadRequest.check_params(req, session)

      assert request.params.file_id
      assert request.params.network_id
      assert request.params.storage_id
      assert request.params.target_id
    end
  end

  describe "check_permission/2" do
    test "henforces the request" do
      {session, %{endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      file = SoftwareSetup.file!(server_id: endpoint.server_id)

      {:ok, [nip]} = CacheQuery.from_server_get_nips(endpoint)

      params = %{
        "file_id" => SoftwareHelper.id() |> to_string(),
        "endpoint_nip" => nip.ip <> "$" <> to_string(nip.network_id)
      }

      req = RequestHelper.mock_request(url_params: params)

      # First attempt.
      assert {:error, _, reason} =
        RequestHelper.check_permissions(PFTPFileDownloadRequest, req, session)

      # Oops, I've added a random file id.
      assert reason == {:file, :not_found}

      # Now let's try again with the correct file id.
      params = %{params| "file_id" => to_string(file.file_id)}
      req = RequestHelper.mock_request(url_params: params)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(PFTPFileDownloadRequest, req, session)

      # Raite, the file exists but it's not on the PFTP server.
      assert reason == {:pftp_file, :not_found}

      # Run the PFTP server and add the file to it.
      SoftwareSetup.PFTP.pftp(server_id: endpoint.server_id)
      SoftwareSetup.PFTP.file(
        server_id: endpoint.server_id,
        file_id: file.file_id
      )

      # Now it's valid!
      assert {:ok, request} =
        RequestHelper.check_permissions(PFTPFileDownloadRequest, req, session)

      # Assigned correct fields to the meta
      assert request.meta.file == file
      assert request.meta.storage
      assert request.meta.gateway.server_id == session.context.gateway.server_id
      assert request.meta.endpoint == endpoint

      # The endpoint storage is NOT the origin's file storage.
      refute request.meta.storage.storage_id == file.storage_id
    end
  end

  describe "handle_request/2" do
    test "it uses values returned on previous step" do
      {session, %{gateway: gateway, endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      file = SoftwareSetup.file!(server_id: endpoint.server_id)

      # Setup the PFTP server and file
      SoftwareSetup.PFTP.pftp(server_id: endpoint.server_id)
      SoftwareSetup.PFTP.file(
        server_id: endpoint.server_id,
        file_id: file.file_id
      )

      {:ok, [nip]} = CacheQuery.from_server_get_nips(endpoint)

      params = %{
        "file_id" => to_string(file.file_id),
        "endpoint_nip" => nip.ip <> "$" <> to_string(nip.network_id)
      }

      # Should've started the process
      request = RequestHelper.mock_request(url_params: params)
      assert {:ok, _} =
        RequestHelper.handle_request(PFTPFileDownloadRequest, request, session)

      # Top!
      [process] = ProcessQuery.get_processes_on_server(gateway.server_id)

      assert process.tgt_file_id == file.file_id
      assert process.gateway_id == gateway.server_id
      assert process.target_id == endpoint.server_id
      assert process.src_connection_id

      refute process.src_file_id
      refute process.tgt_connection_id

      TOPHelper.top_stop(gateway)
    end
  end
end

