defmodule Helix.Network.Request.RemoveTest do

  use Helix.Test.Case.Integration

  alias Helix.Network.Query.Bounce, as: BounceQuery
  alias Helix.Network.Request.Bounce.Remove, as: BounceRemoveRequest

  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Session.Setup, as: SessionSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Network.Setup, as: NetworkSetup

  @session SessionHelper.mock_session!(:server_local)

  describe "check_params/2" do
    test "casts params" do
      {bounce, _} =
        NetworkSetup.Bounce.bounce(entity_id: @session.entity_id)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}

      request = RequestHelper.mock_request(url_params: url)

      assert {:ok, request} =
        BounceRemoveRequest.check_params(request, @session)
      assert request.params.bounce_id == bounce.bounce_id
    end

    test "rejects invalid bounce id" do
      url1 = %{"bounce_id" => "not_an_id"}
      url2 = %{}

      req1 = RequestHelper.mock_request(url_params: url1)
      req2 = RequestHelper.mock_request(url_params: url2)

      assert {:error, _, reason1} =
        BounceRemoveRequest.check_params(req1, @session)
      assert {:error, _, reason2} =
        BounceRemoveRequest.check_params(req2, @session)

      assert reason1 == :bad_request
      assert reason2 == reason1
    end
  end

  describe "check_permissions/2" do
    test "accepts when everything is OK" do
      %{local: %{entity: entity}, session: session} =
        SessionSetup.create_local()

      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: entity.entity_id)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      request = RequestHelper.mock_request(url_params: url)

      assert {:ok, request} =
        RequestHelper.check_permissions(BounceRemoveRequest, request, session)

      assert request.meta.bounce == bounce
    end

    test "rejects when player is not the owner of the bounce" do
      session = SessionSetup.create_local!()
      {bounce, _} = NetworkSetup.Bounce.bounce()

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      request = RequestHelper.mock_request(url_params: url)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(BounceRemoveRequest, request, session)
      assert reason == {:bounce, :not_belongs}
    end

    test "rejects when bounce is being used by a tunnel/connection" do
      %{local: %{entity: entity}, session: session} =
        SessionSetup.create_local()
      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: entity.entity_id)

      # Use the bounce
      NetworkSetup.tunnel(bounce_id: bounce.bounce_id)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      request = RequestHelper.mock_request(url_params: url)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(BounceRemoveRequest, request, session)
      assert reason == {:bounce, :in_use}
    end
  end

  describe "handle_request/2" do
    test "removes the bounce" do
      %{local: %{entity: entity}, session: session} =
        SessionSetup.create_local()

      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: entity.entity_id)

      url = %{"bounce_id" => to_string(bounce.bounce_id)}
      request = RequestHelper.mock_request(url_params: url)

      assert {:ok, _request} =
        RequestHelper.handle_request(BounceRemoveRequest, request, session)

      # Bounce was deleted!
      refute BounceQuery.fetch(bounce.bounce_id)
    end
  end
end
