defmodule Helix.Software.Process.Cracker.BruteforceTest do

  use Helix.Test.Case.Integration

  alias Helix.Network.Query.Tunnel, as: TunnelQuery
  alias Helix.Software.Process.Cracker.Bruteforce, as: BruteforceProcess

  alias Helix.Test.Cache.Helper, as: CacheHelper
  alias Helix.Test.Process.Helper, as: ProcessHelper
  alias Helix.Test.Process.Helper.Processable, as: ProcessableHelper
  alias Helix.Test.Process.Setup, as: ProcessSetup
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  @relay nil

  describe "Process.Executable" do
    test "starts the bruteforce process when everything is OK" do
      {source_server, %{entity: source_entity}} = ServerSetup.server()
      {target_server, _} = ServerSetup.server()

      {file, _} =
        SoftwareSetup.file([type: :cracker, server_id: source_server.server_id])

      target_nip = ServerHelper.get_nip(target_server)

      params = %{
        target_server_ip: target_nip.ip
      }

      meta = %{
        network_id: target_nip.network_id,
        bounce: nil,
        cracker: file
      }

      # Executes Cracker.bruteforce against the target server
      assert {:ok, process} =
        BruteforceProcess.execute(
          source_server, target_server, params, meta, @relay
        )

      # Process data is correct
      assert process.src_connection_id
      assert process.src_file_id == file.file_id
      assert process.type == :cracker_bruteforce
      assert process.gateway_id == source_server.server_id
      assert process.source_entity_id == source_entity.entity_id
      assert process.target_id == target_server.server_id
      assert process.network_id == target_nip.network_id
      assert process.data.target_server_ip == target_nip.ip

      # Bruteforce process has no target file or target connection
      refute process.tgt_file_id
      refute process.tgt_connection_id

      # CrackerBruteforce connection is correct
      connection = TunnelQuery.fetch_connection(process.src_connection_id)

      assert connection.connection_type == :cracker_bruteforce

      # Underlying tunnel is correct
      tunnel = TunnelQuery.fetch(connection.tunnel_id)

      assert tunnel.gateway_id == source_server.server_id
      assert tunnel.target_id == target_server.server_id
      assert tunnel.network_id == target_nip.network_id

      TOPHelper.top_stop(source_server)
      CacheHelper.sync_test()
    end
  end

  describe "Processable" do
    test "after_read_hook/1" do
      {process, _} = ProcessSetup.process(fake_server: true, type: :bruteforce)

      db_process = ProcessHelper.raw_get(process.process_id)

      serialized = ProcessableHelper.after_read_hook(db_process.data)

      assert serialized.target_server_ip

      TOPHelper.top_stop()
    end
  end
end
