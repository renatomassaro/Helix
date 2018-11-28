defmodule Helix.Test.Features.Network.Browse do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  alias HELL.TestHelper.Random
  alias Helix.Test.Cache.Helper, as: CacheHelper
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Session.Setup, as: SessionSetup
  alias Helix.Test.Universe.NPC.Helper, as: NPCHelper

  @internet_str to_string(NetworkHelper.internet_id())

  describe "network.browse" do
    test "valid resolution, originating from my own server" do
      %{local: %{gateway: gateway}, session: session} =
        SessionSetup.create_local()
      {_, npc_ip} = NPCHelper.random()

      params = %{
        "address" => npc_ip
      }

      conn =
        conn()
        |> infer_path(:browse, [gateway.server_id])
        |> set_session(session)
        |> put_body(params)
        |> execute()

      # Make sure the answer is an astounding :ok
      assert_status conn, 200
      response = get_response(conn)

      # It contains the web server content
      assert response.content
      assert response.content.title

      # It contains metadata about the server type (and subtype if applicable)
      # In this case, since it's an NPC, the string must start with `npc_`
      # Example: `npc_download_center` or `npc_bank`
      assert String.starts_with?(response.type, "npc_")

      # It returns the target nip
      assert response.meta.nip == [@internet_str, npc_ip]

      # And the Database password info (in this case it's empty)
      refute response.meta.password

      CacheHelper.sync_test()
    end

    # Context: If player A is connected to B, and makes a `browse`
    # request within the B channel, the source of the request must be server B.
    test "valid resolution, made by player on a remote server" do
      %{
        remote: %{endpoint: endpoint},
        session: session
      } = SessionSetup.create_remote()
      {_, npc_ip} = NPCHelper.random()

      params = %{
        "address" => npc_ip
      }

      # Browse to the NPC ip
      conn =
        conn()
        |> infer_path(:browse, [endpoint.server_id])
        |> set_session(session)
        |> put_body(params)
        |> execute()

      # It worked!
      assert_status conn, 200
      response = get_response(conn)

      # Resolved correctly
      assert response.content
      assert response.content.title
      assert response.meta.nip == [@internet_str, npc_ip]

      # No password
      refute response.meta.password

      # TODO: Once Anycast is implemented, use it to determine whether the
      # correct servers were in fact used for resolution

      CacheHelper.sync_test()
    end

    test "valid resolution, made on remote server with origin headers" do
      %{
        local: %{gateway: gateway},
        remote: %{endpoint: endpoint},
        session: session
      } = SessionSetup.create_remote()
      {_, npc_ip} = NPCHelper.random()

      params = %{
        "address" => npc_ip,
        "origin" => to_string(gateway.server_id)
      }

      # Browse to the NPC ip asking `gateway` to be used as origin
      conn =
        conn()
        |> infer_path(:browse, [endpoint.server_id])
        |> set_session(session)
        |> put_body(params)
        |> execute()

      # It worked!
      assert_status conn, 200
      response = get_response(conn)

      # Resolved correctly
      assert response.content
      assert response.content.title
      assert response.meta.nip == [@internet_str, npc_ip]

      # No password
      refute response.meta.password

      # TODO: Once Anycast is implemented, use it to determine whether the
      # correct servers were in fact used for resolution

      CacheHelper.sync_test()
    end

    test "valid resolution but with invalid `origin` header" do
      %{local: %{gateway: gateway}, session: session} =
        SessionSetup.create_local()
      {_, npc_ip} = NPCHelper.random()

      params = %{
        "address" => npc_ip,
        "origin" => to_string(ServerHelper.id())
      }

      # Browse to the NPC ip asking random server to be used as origin
      conn =
        conn()
        |> infer_path(:browse, [gateway.server_id])
        |> set_session(session)
        |> put_body(params)
        |> execute()

      # It return an error!
      assert_resp_error conn, :bad_origin, 400

      CacheHelper.sync_test()
    end

    test "not found resolution" do
      %{local: %{gateway: gateway}, session: session} =
        SessionSetup.create_local()

      params = %{
        "address" => Random.ipv4()
      }

      # Browse to random IP
      conn =
        conn()
        |> infer_path(:browse, [gateway.server_id])
        |> set_session(session)
        |> put_body(params)
        |> execute()

      # It return an error!
      assert_resp_error conn, :not_found, 404

      CacheHelper.sync_test()
    end

    test "resolution returns list of PublicFTP files" do
      %{
        local: %{gateway: gateway},
        remote: %{endpoint: endpoint},
        session: session
      } = SessionSetup.create_remote()

      # Let's enable the PFTP server on the endpoint...
      SoftwareSetup.PFTP.pftp(server_id: endpoint.server_id)

      # And add 3 files into it.
      SoftwareSetup.PFTP.file(server_id: endpoint.server_id)
      SoftwareSetup.PFTP.file(server_id: endpoint.server_id)
      SoftwareSetup.PFTP.file(server_id: endpoint.server_id)

      endpoint_ip = ServerHelper.get_ip(endpoint)

      params = %{
        "address" => endpoint_ip
      }

      # Browse to the NPC ip
      conn =
        conn()
        |> infer_path(:browse, [gateway.server_id])
        |> set_session(session)
        |> put_body(params)
        |> execute()

      # Make sure the answer is an astounding :ok
      assert_status conn, 200
      response = get_response(conn)

      pftp_files = response.meta.public

      assert length(pftp_files) == 3
    end

    @tag :pending
    test "resolution returning password"

    @tag :pending
    test "resolution of VPC server"
  end
end
