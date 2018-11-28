defmodule Helix.Test.Features.Network.Bounce.Update do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  alias Helix.Network.Query.Bounce, as: BounceQuery

  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Network.Setup, as: NetworkSetup
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Server.Setup, as: ServerSetup

  @internet_id_str to_string(NetworkHelper.internet_id())

  describe "BounceRequest.Update" do
    test "updates the bounce when expected data is given" do
      %{local: %{entity: entity}, session: session} =
        SessionSetup.create_local()

      sse_subscribe(session)

      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: entity.entity_id)

      {server1, _} = ServerSetup.server()
      {server2, _} = ServerSetup.server()

      ip1 = ServerHelper.get_ip(server1)
      ip2 = ServerHelper.get_ip(server2)

      url_params = %{"bounce_id" => to_string(bounce.bounce_id)}
      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => ip1,
            "password" => server1.password
          },
          %{
            "network_id" => @internet_id_str,
            "ip" => ip2,
            "password" => server2.password
          }
        ]
      }

      conn =
        conn()
        |> infer_path(:bounce_update, [bounce.bounce_id])
        |> set_session(session)
        |> put_body(url_params)
        |> put_body(params)
        |> execute()

      assert_empty_response conn
      request_id = get_request_id(conn)

      [bounce_updated_event] = wait_events [:bounce_updated]

      assert bounce_updated_event.meta.request_id == request_id
      assert bounce_updated_event.domain == "account"
      assert bounce_updated_event.domain_id == to_string(entity.entity_id)

      assert bounce_updated_event.data.bounce_id == to_string(bounce.bounce_id)
      assert bounce_updated_event.data.name == params["name"]
      assert [nip1, nip2] = bounce_updated_event.data.links

      assert nip1.network_id == @internet_id_str
      assert nip1.ip == ip1
      assert nip2.network_id == @internet_id_str
      assert nip2.ip == ip2

      # Updated the bounce
      new_bounce = BounceQuery.fetch(bounce.bounce_id)
      assert new_bounce.name == params["name"]
      assert [
        {server1.server_id, @internet_id, ip1},
        {server2.server_id, @internet_id, ip2}
      ] == new_bounce.links
    end

    test "fails when player is not the owner of the bounce" do
      session = SessionSetup.create_local!()

      # Bounce does not belong to `entity`
      {bounce, _} = NetworkSetup.Bounce.bounce()

      {server, _} = ServerSetup.server()
      ip = ServerHelper.get_ip(server)

      url_params = %{"bounce_id" => to_string(bounce.bounce_id)}
      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => ip,
            "password" => server.password
          }
        ],
        "request_id" => "f1ngerpr1nt"
      }

      conn =
        conn()
        |> infer_path(:bounce_update, [bounce.bounce_id])
        |> set_session(session)
        |> put_body(url_params)
        |> put_body(params)
        |> execute()

      assert_resp_error conn, {:bounce, :not_belongs}, 403
    end
  end
end
