defmodule Helix.Process.Public.IndexTest do

  use Helix.Test.Case.Integration

  alias Helix.Process.Public.Index, as: ProcessIndex

  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Process.Setup, as: ProcessSetup
  alias Helix.Test.Process.TOPHelper

  describe "index/1" do
    test "indexes correctly" do
      {server, %{entity: entity}} = ServerSetup.server()
      {remote, _} = ServerSetup.server()

      # Process 1 affects player's own server; started by own player; has no
      # file / connection. Should be returned.
      process1_opts = [
        gateway_id: server.server_id,
        single_server: true,
        type: :bruteforce,
        entity_id: entity.entity_id
      ]
      {process1, _} = ProcessSetup.process(process1_opts)

      # Process 2 affects another server; started by own player, has file and
      # connection. Should be returned.
      process2_destination = remote.server_id
      process2_opts = [
        gateway_id: server.server_id,
        type: :file_download,
        target_id: process2_destination,
        entity_id: entity.entity_id
      ]
      {process2, _} = ProcessSetup.process(process2_opts)

      # Process 3 affects player's own server, started by third-party. Will NOT
      # be returned.
      process3_gateway = remote.server_id
      process3_opts = [
        gateway_id: process3_gateway,
        target_id: server.server_id
      ]
      {_process3, _} = ProcessSetup.process(process3_opts)

      index = ProcessIndex.index(server.server_id, entity.entity_id)

      # There are three processes total
      assert length(index) == 2

      result_process1 = Enum.find(index, &(find_by_id(&1, process1)))
      result_process2 = Enum.find(index, &(find_by_id(&1, process2)))

      assert result_process1.process_id == process1.process_id
      assert result_process2.process_id == process2.process_id

      TOPHelper.top_stop(server.server_id)
    end
  end

  describe "render_index/1" do
    test "returns JSON-friendly, correct result" do
      {server, %{entity: entity}} = ServerSetup.server()
      {remote, _} = ServerSetup.server()

      # Process 1 affects player's own server; started by own player; has no
      # file / connection. Should be returned.
      process1_opts = [
        gateway_id: server.server_id,
        single_server: true,
        type: :bruteforce,
        entity_id: entity.entity_id
      ]
      {process1, _} = ProcessSetup.process(process1_opts)

      # Process 2 affects another server; started by own player, has file and
      # connection. Should be returned.
      process2_destination = remote.server_id
      process2_opts = [
        gateway_id: server.server_id,
        type: :file_download,
        target_id: process2_destination,
        entity_id: entity.entity_id
      ]
      {process2, _} = ProcessSetup.process(process2_opts)

      # Process 3 affects player's own server, started by third-party. Will NOT
      # be returned.
      process3_gateway = remote.server_id
      process3_opts = [
        gateway_id: process3_gateway,
        target_id: server.server_id
      ]
      {_process3, _} = ProcessSetup.process(process3_opts)

      rendered =
        server.server_id
        |> ProcessIndex.index(entity.entity_id)
        |> ProcessIndex.render_index(entity.entity_id)

      # There are three processes total
      assert length(rendered) == 2

      result_process1 = Enum.find(rendered, &(find_by_id_str(&1, process1)))
      result_process2 = Enum.find(rendered, &(find_by_id_str(&1, process2)))

      # Result comes in binary format
      assert is_binary(result_process1.process_id)
      assert is_binary(result_process1.origin_ip)
      assert is_binary(result_process1.target_ip)
      assert is_binary(result_process1.state)
      assert is_binary(result_process1.network_id)
      assert is_binary(result_process1.type)

      # Nil values are nil (not "")
      refute result_process1.source_connection_id

      # Process2 has file data, connection_id
      assert is_binary(result_process2.target_file.id)
      assert is_binary(result_process2.target_file.name)
      assert is_binary(result_process2.source_connection_id)

      # Process2 does not have origin file
      refute result_process2.source_file

      TOPHelper.top_stop(server.server_id)
    end
  end

  defp find_by_id(result, wanted),
    do: result.process_id == wanted.process_id
  defp find_by_id_str(result, wanted),
    do: result.process_id == to_string(wanted.process_id)
end
