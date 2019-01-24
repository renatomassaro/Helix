defmodule Helix.Software.Request.PFTP.File.RemoveTest do

  use Helix.Test.Case.Integration

  alias Helix.Software.Query.PublicFTP, as: PublicFTPQuery
  alias Helix.Software.Request.PFTP.File.Remove, as: PFTPFileRemoveRequest

  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  describe "check_params/2" do
    test "does not allow pftp_file_remove on remote context" do
      session = SessionHelper.mock_session!(:server_remote)

      request = RequestHelper.mock_request()
      assert {:error, _, reason} =
        PFTPFileRemoveRequest.check_params(request, session)

      assert reason == :pftp_must_be_local
    end

    test "requires a valid file_id param" do
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      p0 = %{}
      p1 = %{"file_id" => "I'm not an ID"}

      req0 = RequestHelper.mock_request(unsafe: p0)
      req1 = RequestHelper.mock_request(unsafe: p1)

      assert {:error, _, msg0} =
        PFTPFileRemoveRequest.check_params(req0, session)
      assert {:error, _, msg1} =
        PFTPFileRemoveRequest.check_params(req1, session)

      assert msg0 == :bad_request
      assert msg1 == msg0
    end
  end

  describe "check_permission/2" do
    test "henforces the request goes through PFTPHenforcer.can_enable_server" do
      # Note: this is not intended as an extensive test. For an extended
      # permission test, see `FileHenforcer.PublicFTPTest`.
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)
      server_id = session.context.gateway.server_id

      # This file is not mine!
      file = SoftwareSetup.file!()

      params = %{"file_id" => to_string(file.file_id)}
      request = RequestHelper.mock_request(unsafe: params)

      # Attempts to remove a file from my server
      assert {:error, _, reason} =
        RequestHelper.check_permissions(PFTPFileRemoveRequest, request, session)

      # But I have no PFTP server running :(
      assert reason == {:pftp, :not_found}

      # Ok, run the PFTP Server
      {pftp, _} = SoftwareSetup.PFTP.pftp(server_id: server_id)

      # Try again
      assert {:error, _, reason} =
        RequestHelper.check_permissions(PFTPFileRemoveRequest, request, session)

      # Opsie, I can't remove a file that isn't there ¯\_(ツ)_/¯
      assert reason == {:pftp_file, :not_found}

      # Here, let's add a file
      {pftp_file, _} = SoftwareSetup.PFTP.file(server_id: server_id)

      params = %{"file_id" => to_string(pftp_file.file_id)}
      request = RequestHelper.mock_request(unsafe: params)

      # Worked like a PyCharm
      assert {:ok, request} =
        RequestHelper.check_permissions(PFTPFileRemoveRequest, request, session)

      assert request.meta.pftp == pftp
      assert request.meta.pftp_file == pftp_file
    end

    test "does not remove someone else's file" do
      # This is Tobby
      tobby = ServerSetup.server!()

      # Tobby has a running PFTP Server...
      SoftwareSetup.PFTP.pftp(server_id: tobby.server_id)

      # With a beautiful file inside it
      {tobby_file, _} = SoftwareSetup.PFTP.file(server_id: tobby.server_id)

      # And this is me. I also have a running PFTP Server
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)
      me = session.context.gateway

      SoftwareSetup.PFTP.pftp(server_id: me.server_id)

      # But me is bad and me will try to remove Tobby's file
      params = %{"file_id" => to_string(tobby_file.file_id)}
      request = RequestHelper.mock_request(unsafe: params)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(PFTPFileRemoveRequest, request, session)

      assert reason == {:pftp_file, :not_belongs}
    end
  end

  describe "handle_request/2" do
    test "starts the PFTP server" do
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)
      server_id = session.context.gateway.server_id

      SoftwareSetup.PFTP.pftp(server_id: server_id)
      {pftp_file, _} = SoftwareSetup.PFTP.file(server_id: server_id)

      params = %{"file_id" => to_string(pftp_file.file_id)}
      request = RequestHelper.mock_request(unsafe: params)

      # There is a file there
      assert [_pftp_file] = PublicFTPQuery.list_files(server_id)

      # Removed!
      assert {:ok, _} =
        RequestHelper.handle_request(PFTPFileRemoveRequest, request, session)

      # Not anymore
      assert [] == PublicFTPQuery.list_files(server_id)
    end
  end
end

