defmodule Helix.Software.Request.PFTP.Server.EnableTest do

  use Helix.Test.Case.Integration

  alias Helix.Software.Query.PublicFTP, as: PublicFTPQuery
  alias Helix.Software.Request.PFTP.Server.Enable, as: PFTPServerEnableRequest

  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  describe "check_params/2" do
    test "does not allow pftp_server_enable on remote contexts" do
      session = SessionHelper.mock_session!(:server_remote)

      request = RequestHelper.mock_request()
      assert {:error, _, reason} =
        PFTPServerEnableRequest.check_params(request, session)

      assert reason == :pftp_must_be_local
    end
  end

  describe "check_permission/2" do
    test "henforces the request goes through PFTPHenforcer.can_enable_server" do
      # Note: this is not intended as an extensive test. For an extended
      # permission test, see `FileHenforcer.PublicFTPTest`.
      req = RequestHelper.mock_request()
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      assert {:ok, request} =
        RequestHelper.check_permissions(PFTPServerEnableRequest, req, session)

      assert request.meta.server.server_id == session.context.gateway.server_id

      # Now we'll enable pftp on that server, so the request should fail
      SoftwareSetup.PFTP.pftp(server_id: session.context.gateway.server_id)

      # Now it fails because it's already enabled
      assert {:error, _, reason} =
        RequestHelper.check_permissions(PFTPServerEnableRequest, req, session)

      assert reason == :pftp_already_enabled
    end
  end

  describe "handle_request/2" do
    test "starts the PFTP server" do
      req = RequestHelper.mock_request()
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      # No PFTP server running
      refute PublicFTPQuery.fetch_server(session.context.gateway.server_id)

      assert {:ok, _} =
        RequestHelper.handle_request(PFTPServerEnableRequest, req, session)

      # Now it is running!
      pftp = PublicFTPQuery.fetch_server(session.context.gateway.server_id)
      assert pftp.is_active
    end
  end
end
