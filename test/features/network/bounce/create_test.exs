defmodule Helix.Test.Features.Network.Bounce.Create do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  alias Helix.Network.Model.Bounce
  alias Helix.Network.Query.Bounce, as: BounceQuery

  alias HELL.TestHelper.Random
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Server.Setup, as: ServerSetup

  @internet_id_str to_string(NetworkHelper.internet_id())

  describe "BounceRequest.Create" do
    test "creates the bounce when expected data is given" do
      %{local: %{entity: entity}, session: session} =
        SessionSetup.create_local()

      sse_subscribe(session)

      {server1, _} = ServerSetup.server()
      {server2, _} = ServerSetup.server()

      ip1 = ServerHelper.get_ip(server1)
      ip2 = ServerHelper.get_ip(server2)

      params = %{
        "name" => "lula_preso_Amanda",
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
        |> infer_path(:bounce_create)
        |> set_session(session)
        |> put_body(params)
        |> execute()

      assert_empty_response conn
      request_id = get_request_id(conn)

      [bounce_created_event] = wait_events [:bounce_created]

      assert bounce_created_event.meta.request_id == request_id
      assert bounce_created_event.domain == "account"
      assert bounce_created_event.domain_id == to_string(entity.entity_id)

      assert bounce_created_event.data.name == params["name"]
      assert length(bounce_created_event.data.links) == length(params["links"])

      bounce =
        bounce_created_event.data.bounce_id
        |> Bounce.ID.cast!()
        |> BounceQuery.fetch()

      assert bounce.entity_id == entity.entity_id
      Enum.reduce(bounce.links, 0, fn {link_server_id, _, link_ip}, order ->
        {expected_server, expected_ip} =
          if order == 0 do
            {server1, ip1}
          else
            {server2, ip2}
          end

        assert link_server_id == expected_server.server_id
        assert link_ip == expected_ip
      end)
    end

    test "fails when player does not have access to bounce servers" do
      session = SessionSetup.create_local!()

      {server1, _} = ServerSetup.server()
      {server2, _} = ServerSetup.server()

      ip1 = ServerHelper.get_ip(server1)
      ip2 = ServerHelper.get_ip(server2)

      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => ip1,
            "password" => Random.password()
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
        |> infer_path(:bounce_create)
        |> set_session(session)
        |> put_body(params)
        |> execute()

      assert_resp_error conn, {:bounce, :no_access}, 403
    end
  end
end
