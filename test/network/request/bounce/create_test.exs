defmodule Helix.Network.Request.Bounce.CreateTest do

  use Helix.Test.Case.Integration

  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Network.Request.Bounce.Create, as: BounceCreateRequest

  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Network.Helper, as: NetworkHelper

  @session SessionHelper.mock_session!(:server_local)
  @internet_id NetworkHelper.internet_id()
  @internet_id_str to_string(@internet_id)

  describe "check_params/2" do
    test "casts params" do
      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{"network_id" => "::", "ip" => "1.2.3.4", "password" => "abc"},
          %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
        ]
      }

      request = RequestHelper.mock_request(unsafe: params)
      assert {:ok, request} =
        BounceCreateRequest.check_params(request, @session)

      assert request.params.name == params["name"]
      Enum.each(request.params.links, fn link ->
        assert link.network_id == @internet_id
        assert is_binary(link.ip)
        assert is_binary(link.password)
      end)
    end

    test "validates bounce name" do
      params = %{
        "name" => "()[]-_;,@#@#@@#",
        "links" => [
          %{"network_id" => "::", "ip" => "1.2.3.4", "password" => "abc"},
          %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
        ]
      }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:error, _, reason} =
        BounceCreateRequest.check_params(request, @session)
      assert reason == :bad_request
    end

    test "validates links" do
      base_params = %{"name" => "valid_name"}

      p1 = %{
        "links" => [
          %{"network_id" => "invalid", "ip" => "1.2.3.4", "password" => "abc"},
          %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
        ]
      } |> Map.merge(base_params)

      p2 = %{
        "links" => [
          %{"network_id" => "::", "ip" => "invalid", "password" => "abc"},
          %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
        ]
      } |> Map.merge(base_params)

      p3 = %{
        "links" => [
          %{"network_id" => "::", "ip" => "1.2.3.4", "password" => nil},
          %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
        ]
      } |> Map.merge(base_params)

      p4 = %{
        "links" => [%{"network_id" => "::"}, %{"foo" => true}]
      } |> Map.merge(base_params)

      req1 = RequestHelper.mock_request(unsafe: p1)
      req2 = RequestHelper.mock_request(unsafe: p2)
      req3 = RequestHelper.mock_request(unsafe: p3)
      req4 = RequestHelper.mock_request(unsafe: p4)

      assert {:error, _, r1} = BounceCreateRequest.check_params(req1, @session)
      assert {:error, _, r2} = BounceCreateRequest.check_params(req2, @session)
      assert {:error, _, r3} = BounceCreateRequest.check_params(req3, @session)
      assert {:error, _, r4} = BounceCreateRequest.check_params(req4, @session)

      assert r1 == :bad_link
      assert r2 == r1
      assert r3 == r2
      assert r4 == r3
    end
  end

  describe "check_permissions/2" do
    test "accepts when everything is OK" do
      {server1, _} = ServerSetup.server()
      {server2, _} = ServerSetup.server()

      ip1 = ServerHelper.get_ip(server1)
      ip2 = ServerHelper.get_ip(server2)

      params =
        %{
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

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, request} =
        RequestHelper.check_permissions(BounceCreateRequest, request, @session)

      assert request.meta.servers == [server1, server2]
    end

    test "rejects when password is wrong" do
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
            "password" => server2.password  # Using password from another server
          },
          %{
            "network_id" => @internet_id_str,
            "ip" => ip2,
            "password" => server1.password  # Using password from another server
          }
        ]
      }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(BounceCreateRequest, request, @session)

      assert reason == {:bounce, :no_access}
    end

    test "rejects when NIP is wrong" do
      {server, _} = ServerSetup.server()
      ip = ServerHelper.get_ip(server)

      base_params = %{"name" => "lula_preso_amanha"}

      p1 = %{
        "links" => [
          %{
            "network_id" => NetworkHelper.id(),  # Random network
            "ip" => ip,
            "password" => server.password
          }
        ]
      } |> Map.merge(base_params)

      p2 = %{
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => NetworkHelper.ip(),  # Random ip
            "password" => server.password
          }
        ]
      } |> Map.merge(base_params)

      req1 = RequestHelper.mock_request(unsafe: p1)
      req2 = RequestHelper.mock_request(unsafe: p2)

      assert {:error, _, reason1} =
        RequestHelper.check_permissions(BounceCreateRequest, req1, @session)
      assert {:error, _, reason2} =
        RequestHelper.check_permissions(BounceCreateRequest, req2, @session)

      assert reason1 == {:nip, :not_found}
      assert reason2 == reason1
    end
  end

  describe "handle_request/2" do
    test "creates the bounce when everything is OK" do
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
            "password" => server1.password
          },
          %{
            "network_id" => @internet_id_str,
            "ip" => ip2,
            "password" => server2.password
          }
        ]
      }

      request = RequestHelper.mock_request(unsafe: params)

      # Bounce creation upon request is asynchronous (and we don't have a
      # channel to listen for events), so we can't verify the bounce creation
      # through the returned request (as it doesn't return anything)
      assert {:ok, _request} =
        RequestHelper.handle_request(BounceCreateRequest, request, @session)

      # Entity has one bounce assigned to her
      assert [bounce] = EntityQuery.get_bounces(@session.entity_id)

      # Links and name are valid
      assert [
        {server1.server_id, @internet_id, ip1},
        {server2.server_id, @internet_id, ip2},
      ] == bounce.links
      assert bounce.name == params["name"]
    end
  end
end
