defmodule Helix.Server.Websocket.Channel.Server.Topics.CrackerTest do

  use Helix.Test.Case.Integration

  import Phoenix.ChannelTest
  import Helix.Test.Channel.Macros
  import Helix.Test.Macros

  alias Helix.Cache.Query.Cache, as: CacheQuery
  alias Helix.Network.Model.Connection
  alias Helix.Network.Query.Tunnel, as: TunnelQuery
  alias Helix.Process.Model.Process
  alias Helix.Process.Query.Process, as: ProcessQuery

  alias Helix.Test.Channel.Setup, as: ChannelSetup
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup
  alias Helix.Test.Server.Setup, as: ServerSetup

  describe "cracker.bruteforce" do
    test "bruteforce attack is started" do
      {socket, %{gateway: gateway}} =
        ChannelSetup.join_server([own_server: true])

      {target, _} = ServerSetup.server()

      {:ok, [target_nip]} =
        CacheQuery.from_server_get_nips(target.server_id)

      {_cracker, _} =
        SoftwareSetup.file([type: :cracker, server_id: gateway.server_id])

      params = %{
        network_id: to_string(target_nip.network_id),
        ip: target_nip.ip,
        bounce_id: nil
      }

      # Submit request
      ref = push socket, "cracker.bruteforce", params

      # Wait for response
      assert_reply ref, :ok, %{data: %{}}, timeout(:slow)

      [process_created_event] = wait_events [:process_created]

      # All required fields are there
      assert process_created_event.data.type == "cracker_bruteforce"
      refute process_created_event.data.target_file
      assert process_created_event.data.origin_ip
      assert process_created_event.data.priority
      assert process_created_event.data.usage
      assert process_created_event.data.network_id
      assert process_created_event.data.state
      assert process_created_event.data.progress
      assert process_created_event.data.target_ip
      assert process_created_event.data.source_file

      process_id = Process.ID.cast!(process_created_event.data.process_id)
      connection_id =
        Connection.ID.cast!(process_created_event.data.source_connection_id)

      # It definitely worked. Yay!
      assert ProcessQuery.fetch(process_id)
      assert TunnelQuery.fetch_connection(connection_id)

      TOPHelper.top_stop(gateway)
    end

    test "attempt to crack without a cracker" do
      {socket, %{gateway: _}} =
        ChannelSetup.join_server([own_server: true])

      {target, _} = ServerSetup.server()

      {:ok, [target_nip]} =
        CacheQuery.from_server_get_nips(target.server_id)

      params = %{
        network_id: to_string(target_nip.network_id),
        ip: target_nip.ip,
        bounce_id: nil
      }

      # Submit request
      ref = push socket, "cracker.bruteforce", params
      assert_reply ref, :error, response, timeout(:fast)

      assert response.data.message == "cracker_not_found"
    end
  end
end
