defmodule Helix.Test.Features.Hack do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  import Helix.Test.Case.ID
  import Helix.Test.Macros

  alias HELL.DateUtils
  alias Helix.Entity.Query.Database, as: DatabaseQuery
  alias Helix.Network.Model.Connection
  alias Helix.Network.Query.Tunnel, as: TunnelQuery
  alias Helix.Process.Model.Process
  alias Helix.Process.Query.Process, as: ProcessQuery
  alias Helix.Server.Websocket.Channel.Server, as: ServerChannel

  alias Helix.Test.Network.Setup, as: NetworkSetup
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Server.Setup, as: ServerSetup

  @moduletag :feature

  describe "crack" do
    test "crack (bruteforce) life cycle" do
      %{
        local: %{gateway: gateway, entity: entity},
        session: session
      } = SessionSetup.create_local()

      sse_subscribe(session)

      target = ServerSetup.server!()
      target_nip = ServerHelper.get_nip(target)

      SoftwareSetup.cracker(server_id: gateway.server_id)

      bounce = NetworkSetup.Bounce.bounce!(entity_id: entity.entity_id)

      params = %{
        "bounce_id" => to_string(bounce.bounce_id)
      }

      base_conn =
        conn()
        |> infer_path(:bruteforce, [gateway.server_id, target_nip])
        |> set_session(session)
        |> put_body(params)

      conn = execute(base_conn)
      request_id = get_request_id(conn)

      # It worked!
      assert_status conn, 200

      [process_created] = wait_events [:process_created]

      assert process_created.data.type == "cracker_bruteforce"
      assert process_created.meta.request_id == request_id
      assert process_created.domain == "server"
      assert process_created.domain_id == to_string(gateway.server_id)

      process_id = Process.ID.cast!(process_created.data.process_id)
      process = ProcessQuery.fetch(process_id)

      connection_id =
        Connection.ID.cast!(process_created.data.source_connection_id)

      # The BruteforceProcess is running as expected
      process = ProcessQuery.fetch(process_id)

      assert process.gateway_id == gateway.server_id
      assert process.target_id == target.server_id
      assert process.type == :cracker_bruteforce
      assert process.data.target_server_ip == target_nip.ip

      tunnel =
        connection_id
        |> TunnelQuery.fetch_connection()
        |> TunnelQuery.fetch_from_connection()

      # Attack is using the requested bounce
      assert tunnel.gateway_id == gateway.server_id
      assert tunnel.target_id == target.server_id
      assert tunnel.bounce_id == bounce.bounce_id

      # Let's cheat and finish the process right now
      TOPHelper.force_completion(process)

      # And soon we'll receive the following events
      [password_acquired, process_completed, notification_added] =
        wait_events [
          :server_password_acquired, :process_completed, :notification_added
        ]
      assert password_acquired.event == "server_password_acquired"

      # ServerPasswordAcquired includes data about the server we've just hacked!
      assert_id password_acquired.data.network_id, target_nip.network_id
      assert password_acquired.data.server_ip == target_nip.ip
      assert password_acquired.data.password

      # We'll receive the generic ProcessCompletedEvent
      assert process_completed.event == "process_completed"

      # And the notification that we've just hacked that server
      assert notification_added.data.data.password == target.password
      assert notification_added.data.data.ip == target_nip.ip
      assert notification_added.data.data.network_id ==
        to_string(target_nip.network_id)

      db_server =
        DatabaseQuery.fetch_server(
          entity.entity_id, target_nip.network_id, target_nip.ip
        )

      # The hacked server has been added to my Database
      assert db_server
      assert db_server.password == password_acquired.data.password
      assert db_server.last_update > DateUtils.date_before(1)

      TOPHelper.top_stop(gateway)
    end
  end

  # describe "remote login" do
  #   test "player can login another server when correct password is given" do
  #     {socket, %{gateway: gateway}} =
  #       ChannelSetup.join_server([own_server: true])

  #     {target, _} = ServerSetup.server()

  #     target_nip = ServerHelper.get_nip(target)

  #     gateway_ip = ServerHelper.get_ip(gateway)

  #     topic =
  #       ChannelHelper.server_topic_name(target_nip.network_id, target_nip.ip)
  #     params = %{
  #       "gateway_ip" => gateway_ip,
  #       "password" => target.password
  #     }

  #     # So, let's login!
  #     {:ok, %{data: bootstrap}, new_socket} =
  #       subscribe_and_join(socket, ServerChannel, topic, params)

  #     # Successfully joined the remote server channel
  #     assert new_socket.topic == topic
  #     assert new_socket.assigns.gateway.server_id == gateway.server_id
  #     assert new_socket.assigns.destination.server_id == target.server_id

  #     # Logging in returns the remote server data
  #     assert bootstrap.main_storage
  #     assert bootstrap.storages
  #     assert bootstrap.logs
  #     assert bootstrap.processes
  #   end

  #   @tag :pending
  #   test "server password is stored on the DB in case it wasn't already"
  # end
end
