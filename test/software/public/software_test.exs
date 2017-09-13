defmodule Helix.Software.Public.FileTest do

  use Helix.Test.Case.Integration

  alias Helix.Cache.Query.Cache, as: CacheQuery
  alias Helix.Software.Public.File, as: FilePublic

  alias Helix.Test.Cache.Helper, as: CacheHelper
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  describe "bruteforce/4" do
    test "starts a bruteforce attack" do
      {source_server, %{entity: source_entity}} = ServerSetup.server()
      {target_server, _} = ServerSetup.server()

      {:ok, [target_nip]} =
        CacheQuery.from_server_get_nips(target_server.server_id)

      {cracker, _} =
        SoftwareSetup.file([type: :cracker, server_id: source_server.server_id])

      # Start the process from public
      assert {:ok, process} =
        FilePublic.bruteforce(
          source_server.server_id,
          target_nip.network_id,
          target_nip.ip,
          [])

      assert process.connection_id
      assert process.gateway_id == source_server.server_id
      assert process.target_server_id == target_server.server_id
      assert process.network_id == target_nip.network_id
      assert process.file_id == cracker.file_id
      assert process.source_entity_id == source_entity.entity_id
      assert process.process_data.target_server_ip == target_nip.ip

      :timer.sleep(100)
      TOPHelper.top_stop(source_server.server_id)
      CacheHelper.sync_test()
    end

    test "fails if no cracker is present" do
      {source_server, _} = ServerSetup.server()
      {target_server, _} = ServerSetup.server()

      {:ok, [target_nip]} =
        CacheQuery.from_server_get_nips(target_server.server_id)

      # Attempts to start the process on a server that has no cracker
      assert {:error, %{message: msg}} =
        FilePublic.bruteforce(
          source_server.server_id,
          target_nip.network_id,
          target_nip.ip,
          [])

      assert msg == "cracker_not_found"

      CacheHelper.sync_test()
    end
  end
end
