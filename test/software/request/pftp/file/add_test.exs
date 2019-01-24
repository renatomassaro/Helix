defmodule Helix.Software.Request.PFTP.File.AddTest do

  use Helix.Test.Case.Integration

  alias Helix.Software.Query.PublicFTP, as: PublicFTPQuery
  alias Helix.Software.Request.PFTP.File.Add, as: PFTPFileAddRequest

  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  describe "check_params/2" do
    test "does not allow pftp_file_add on remote context" do
      session = SessionHelper.mock_session!(:server_remote)

      request = RequestHelper.mock_request()
      assert {:error, _, reason} =
        PFTPFileAddRequest.check_params(request, session)

      assert reason == :pftp_must_be_local
    end

    test "requires a valid file_id param" do
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      p0 = %{}
      p1 = %{"file_id" => "I'm not an ID"}

      req0 = RequestHelper.mock_request(unsafe: p0)
      req1 = RequestHelper.mock_request(unsafe: p1)

      assert {:error, _, msg0} = PFTPFileAddRequest.check_params(req0, session)
      assert {:error, _, msg1} = PFTPFileAddRequest.check_params(req1, session)

      assert msg0 == :bad_request
      assert msg1 == msg0
    end
  end

  describe "check_permission/2" do
    test "henforces the request goes through PFTPHenforcer.can_enable_server" do
      # Note: this is not intended as an extensive test. For an extended
      # permission test, see `FileHenforcer.PublicFTPTest`.
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      # This file is not mine!
      file = SoftwareSetup.file!()

      params = %{"file_id" => to_string(file.file_id)}
      request = RequestHelper.mock_request(unsafe: params)

      # Attempts to add a file to my server
      assert {:error, _, reason} =
        RequestHelper.check_permissions(PFTPFileAddRequest, request, session)

      # But I have no PFTP server running :(
      assert reason == {:pftp, :not_found}

      # Ok, run the PFTP Server
      {pftp, _} =
        SoftwareSetup.PFTP.pftp(server_id: session.context.gateway.server_id)

      # Try again
      assert {:error, _, reason} =
        RequestHelper.check_permissions(PFTPFileAddRequest, request, session)

      # Opsie, that file is not mine 😂
      assert reason == {:file, :not_belongs}

      # Here, this file is mine
      file = SoftwareSetup.file!(server_id: session.context.gateway.server_id)

      params = %{"file_id" => to_string(file.file_id)}
      request = RequestHelper.mock_request(unsafe: params)

      # Worked like a PyCharm
      assert {:ok, request} =
        RequestHelper.check_permissions(PFTPFileAddRequest, request, session)

      assert request.meta.pftp == pftp
      assert request.meta.file == file
    end
  end

  describe "handle_request/2" do
    test "starts the PFTP server" do
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)
      file = SoftwareSetup.file!(server_id: session.context.gateway.server_id)

      # Assume a PFTP Server is running
      SoftwareSetup.PFTP.pftp(server_id: session.context.gateway.server_id)

      params = %{"file_id" => to_string(file.file_id)}
      request = RequestHelper.mock_request(unsafe: params)

      # Added!
      assert {:ok, _} =
        RequestHelper.handle_request(PFTPFileAddRequest, request, session)

      # Yep, it's there
      [pftp_file] = PublicFTPQuery.list_files(session.context.gateway.server_id)
      assert pftp_file == file
    end
  end
end
