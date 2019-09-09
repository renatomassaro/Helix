defmodule Helix.Account.Request.SyncTest do

  use Helix.Test.Case.Integration

  alias Helix.Account.Request.Sync, as: SyncRequest

  alias Helix.Test.Session.Setup, as: SessionSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Account.Setup, as: AccountSetup

  # describe "handle_request/2" do
  #   test "handles session with gateway data" do
  #     session = create_local_session()


  #     params = %{"client" => "web1"}
  #     request = RequestHelper.mock_request(unsafe: params)

  #     RequestHelper.handle_request(SyncRequest, request, session)
  #   end

  #   test "handles session with remote data" do
  #     session = create_remote_session()

  #     params = %{"client" => "web1"}
  #     request = RequestHelper.mock_request(unsafe: params)

  #     RequestHelper.handle_request(SyncRequest, request, session)
  #   end
  # end

  describe "render_response/2" do
    test "handles session with gateway data" do
      session = create_local_session()

      params = %{"client" => "web1"}
      request = RequestHelper.mock_request(unsafe: params)

      {:ok, %{response: response}} =
        RequestHelper.render_response(SyncRequest, request, session)

      bootstrap_account = response.bootstrap.account
      assert Enum.empty?(bootstrap_account.servers.remote)

      bootstrap_servers = response.bootstrap.servers
      assert length(bootstrap_servers |> Map.to_list()) == 2
    end

    test "handles session with remote data" do
      session = create_remote_session()

      params = %{"client" => "web1"}
      request = RequestHelper.mock_request(unsafe: params)

      {:ok, %{response: response}} =
        RequestHelper.render_response(SyncRequest, request, session)

      assert response.account_id == session.local.account.account_id

      bootstrap_account = response.bootstrap.account
      assert length(bootstrap_account.servers.remote) == 1

      bootstrap_servers = response.bootstrap.servers
      assert length(bootstrap_servers |> Map.to_list()) == 3
    end
  end


  defp create_local_session do
    account = AccountSetup.account!(with_server: true)

    SessionSetup.create(
      local: [account: account], remote: nil, meta: [skip_sync: true]
    )
  end

  defp create_remote_session do
    local_account = AccountSetup.account!(with_server: true)
    remote_account = AccountSetup.account!(with_server: true)

    local_opts = [account: local_account]
    remote_opts = [account: remote_account]

    SessionSetup.create(
      local: local_opts, remote: remote_opts, meta: [skip_sync: true]
    )
  end
end
