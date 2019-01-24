defmodule Helix.Software.Request.PFTP.Server.DisableTest do

  use Helix.Test.Case.Integration

  alias Helix.Software.Action.PublicFTP, as: PublicFTPAction
  alias Helix.Software.Query.PublicFTP, as: PublicFTPQuery
  alias Helix.Software.Request.PFTP.Server.Disable, as: PFTPServerDisableRequest

  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  describe "check_params/2" do
    test "does not allow pftp_server_disable on remote contexts" do
      session = SessionHelper.mock_session!(:server_remote)

      request = RequestHelper.mock_request()
      assert {:error, _, reason} =
        PFTPServerDisableRequest.check_params(request, session)

      assert reason == :pftp_must_be_local
    end
  end

  describe "check_permission/2" do
    test "henforces the request through PFTPHenforcer.can_disable_server" do
      # Note: this is not intended as an extensive test. For an extended
      # permission test, see `FileHenforcer.PublicFTPTest`.
      req = RequestHelper.mock_request()
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      {pftp, _} =
        SoftwareSetup.PFTP.pftp(server_id: session.context.gateway.server_id)

      assert {:ok, request} =
        RequestHelper.check_permissions(PFTPServerDisableRequest, req, session)
      assert request.meta.pftp == pftp

      # Now we'll try again with the pftp server disabled
      PublicFTPAction.disable_server(pftp)

      # Now it fails because it's already disabled
      assert {:error, _, reason} =
        RequestHelper.check_permissions(PFTPServerDisableRequest, req, session)

      assert reason == :pftp_already_disabled
    end
  end

  describe "handle_request/2" do
    test "stops the PFTP server" do
      req = RequestHelper.mock_request()
      session = SessionHelper.mock_session!(:server_local, with_gateway: true)

      # Start the PFTP server
      SoftwareSetup.PFTP.pftp(server_id: session.context.gateway.server_id)

      assert {:ok, _} =
        RequestHelper.handle_request(PFTPServerDisableRequest, req, session)

      # Now it is stopped
      pftp = PublicFTPQuery.fetch_server(session.context.gateway.server_id)
      refute pftp.is_active
    end
  end
end
