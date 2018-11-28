defmodule Helix.Network.Request.Bounce.UpdateTest do

  use Helix.Test.Case.Integration

  alias Helix.Network.Request.Bounce.Update, as: BounceUpdateRequest
  alias Helix.Network.Query.Bounce, as: BounceQuery

  alias HELL.TestHelper.Random
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Session.Setup, as: SessionSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Network.Setup, as: NetworkSetup

  @session SessionHelper.mock_session!(:server_local)
  @internet_id NetworkHelper.internet_id()
  @internet_id_str to_string(@internet_id)

  describe "check_params/2" do
    test "casts params" do
      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: @session.entity_id)

      # `p1` has both `name` and `links` set
      url1 = %{"bounce_id" => to_string(bounce.bounce_id)}
      p1 =
        %{
          "name" => NetworkHelper.Bounce.name(),
          "links" => [
            %{"network_id" => "::", "ip" => "1.2.3.4", "password" => "abc"},
            %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
          ]
        }

      # `p2` only has `name` set
      url2 = %{"bounce_id" => to_string(bounce.bounce_id)}
      p2 =
        %{
          "name" => NetworkHelper.Bounce.name()
        }

      # `p3` only has `links` set
      url3 = %{"bounce_id" => to_string(bounce.bounce_id)}
      p3 =
        %{
          "links" => [
            %{"network_id" => "::", "ip" => "1.2.3.4", "password" => "abc"},
            %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
          ]
        }

      req1 = RequestHelper.mock_request(unsafe: p1, url_params: url1)
      req2 = RequestHelper.mock_request(unsafe: p2, url_params: url2)
      req3 = RequestHelper.mock_request(unsafe: p3, url_params: url3)

      assert {:ok, req1} = BounceUpdateRequest.check_params(req1, @session)
      assert {:ok, req2} = BounceUpdateRequest.check_params(req2, @session)
      assert {:ok, req3} = BounceUpdateRequest.check_params(req3, @session)

      # req1 must update both `name` and `links`
      assert req1.params.bounce_id == bounce.bounce_id
      assert req1.params.new_name == p1["name"]
      Enum.each(req1.params.new_links, fn link ->
        assert link.network_id == @internet_id
        assert is_binary(link.ip)
        assert is_binary(link.password)
      end)

      # req2 only updates the name
      assert req1.params.bounce_id == bounce.bounce_id
      assert req2.params.new_name == p2["name"]
      refute req2.params.new_links

      # req3 only updates the links
      assert req1.params.bounce_id == bounce.bounce_id
      refute req3.params.new_name
      Enum.each(req3.params.new_links, fn link ->
        assert link.network_id == @internet_id
        assert is_binary(link.ip)
        assert is_binary(link.password)
      end)
    end

    test "requires bounce ID" do
      url1 = %{"bounce_id" => "not_an_id"}
      p1 = %{"name" => "blar"}

      p2 = %{"name" => "wit"}

      req1 = RequestHelper.mock_request(unsafe: p1, url_params: url1)
      req2 = RequestHelper.mock_request(unsafe: p2)

      assert {:error, _, er1} = BounceUpdateRequest.check_params(req1, @session)
      assert {:error, _, er2} = BounceUpdateRequest.check_params(req2, @session)

      assert er1 == :bad_request
      assert er2 == er1
    end

    test "requires at least one change (`name` or `links`)" do
      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: @session.entity_id)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}

      request = RequestHelper.mock_request(url_params: url)

      assert {:error, _, reason} =
        BounceUpdateRequest.check_params(request, @session)
      assert reason == :no_changes
    end

    test "validates bounce name" do
      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: @session.entity_id)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      params = %{"name" => "($*%(@$*&%(@$%*&#@)))"}

      request = RequestHelper.mock_request(unsafe: params, url_params: url)

      assert {:error, _, reason} =
        BounceUpdateRequest.check_params(request, @session)
      assert reason == :bad_request
    end

    test "validates links" do
      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: @session.entity_id)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}

      p1 = %{
        "name" => NetworkHelper.Bounce.name(),
        "links" => [
          %{"network_id" => "invalid", "ip" => "1.2.3.4", "password" => "abc"},
          %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
        ]
      }

      p2 = %{
        "links" => [
          %{"network_id" => "::", "ip" => "invalid", "password" => "abc"},
          %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
        ]
      }

      p3 = %{
        "links" => [
          %{"network_id" => "::", "ip" => "1.2.3.4", "password" => nil},
          %{"network_id" => "::", "ip" => "4.3.2.1", "password" => "cba"}
        ]
      }

      p4 = %{
        "links" => [%{"network_id" => "::"}, %{"foo" => true}]
      }

      req1 = RequestHelper.mock_request(unsafe: p1, url_params: url)
      req2 = RequestHelper.mock_request(unsafe: p2, url_params: url)
      req3 = RequestHelper.mock_request(unsafe: p3, url_params: url)
      req4 = RequestHelper.mock_request(unsafe: p4, url_params: url)

      assert {:error, _, reason1} =
        BounceUpdateRequest.check_params(req1, @session)
      assert {:error, _, reason2} =
        BounceUpdateRequest.check_params(req2, @session)
      assert {:error, _, reason3} =
        BounceUpdateRequest.check_params(req3, @session)
      assert {:error, _, reason4} =
        BounceUpdateRequest.check_params(req4, @session)

      assert reason1 == :bad_link
      assert reason2 == reason1
      assert reason3 == reason2
      assert reason4 == reason3
    end
  end

  describe "check_permissions/2" do
    test "accepts when everything is OK" do
      %{
        local: %{entity: entity},
        session: session
      } = SessionSetup.create_local()

      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: session.entity_id)

      {server, _} = ServerSetup.server()
      ip = ServerHelper.get_ip(server)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => ip,
            "password" => server.password,
          }
        ]
      }

      request = RequestHelper.mock_request(unsafe: params, url_params: url)

      assert {:ok, request} =
        RequestHelper.check_permissions(BounceUpdateRequest, request, session)

      assert request.meta.entity == entity
      assert request.meta.bounce == bounce
      assert request.meta.servers == [server]
    end

    test "rejects when entity is not the owner of the bounce" do
      {bounce, _} = NetworkSetup.Bounce.bounce()

      {server, _} = ServerSetup.server()
      ip = ServerHelper.get_ip(server)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => ip,
            "password" => server.password,
          }
        ]
      }

      request = RequestHelper.mock_request(unsafe: params, url_params: url)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(BounceUpdateRequest, request, @session)

      assert reason == {:entity, :not_found}
    end

    test "rejects when bounce is being used" do
      %{
        local: %{entity: entity},
        session: session
      } = SessionSetup.create_local()

      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: entity.entity_id)

      # Start using the bounce
      NetworkSetup.tunnel(bounce_id: bounce.bounce_id)

      {server, _} = ServerSetup.server()
      ip = ServerHelper.get_ip(server)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => ip,
            "password" => server.password,
          }
        ]
      }

    request = RequestHelper.mock_request(unsafe: params, url_params: url)

    assert {:error, _, reason} =
      RequestHelper.check_permissions(BounceUpdateRequest, request, session)

     assert reason == {:bounce, :in_use}
    end

    test "rejects when password is wrong" do
      %{
        local: %{entity: entity},
        session: session
      } = SessionSetup.create_local()

      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: entity.entity_id)

      {server1, _} = ServerSetup.server()
      {server2, _} = ServerSetup.server()

      ip1 = ServerHelper.get_ip(server1)
      ip2 = ServerHelper.get_ip(server2)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => ip1,
            "password" => Random.password(),
          },
          %{
            "network_id" => @internet_id_str,
            "ip" => ip2,
            "password" => server2.password
          }
        ]
      }

      request = RequestHelper.mock_request(unsafe: params, url_params: url)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(BounceUpdateRequest, request, session)

      assert reason == {:bounce, :no_access}
    end

    test "rejects when NIP is wrong" do
      %{
        local: %{entity: entity},
        session: session
      } = SessionSetup.create_local()

      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: entity.entity_id)

      {server, _} = ServerSetup.server()

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => NetworkHelper.ip(),
            "password" => server.password,
          }
        ]
      }

      request = RequestHelper.mock_request(unsafe: params, url_params: url)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(BounceUpdateRequest, request, session)

      assert reason == {:nip, :not_found}
    end
  end

  describe "handle_request/2" do
    test "updates the bounce when everything is ok" do
      %{
        local: %{entity: entity},
        session: session
      } = SessionSetup.create_local()

      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: entity.entity_id)

      {server, _} = ServerSetup.server()
      ip = ServerHelper.get_ip(server)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      params = %{
        "name" => "lula_preso_amanha",
        "links" => [
          %{
            "network_id" => @internet_id_str,
            "ip" => ip,
            "password" => server.password,
          }
        ]
      }

      request = RequestHelper.mock_request(unsafe: params, url_params: url)

      assert {:ok, _request} =
        RequestHelper.handle_request(BounceUpdateRequest, request, session)

      new_bounce = BounceQuery.fetch(bounce.bounce_id)

      assert new_bounce.name == params["name"]
      assert new_bounce.links == [{server.server_id, @internet_id, ip}]
      assert new_bounce.entity_id == entity.entity_id
    end
  end
end
