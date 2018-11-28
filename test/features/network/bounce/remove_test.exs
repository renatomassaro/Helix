defmodule Helix.Test.Features.Network.Bounce.Remove do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  alias Helix.Network.Query.Bounce, as: BounceQuery

  alias Helix.Test.Network.Setup, as: NetworkSetup

  describe "BounceRequest.Remove" do
    test "removes the bounce when everything is OK" do
      %{local: %{entity: entity}, session: session} =
        SessionSetup.create_local()

      sse_subscribe(session)

      {bounce, _} = NetworkSetup.Bounce.bounce(entity_id: entity.entity_id)

      url_params = %{"bounce_id" => to_string(bounce.bounce_id)}

      conn =
        conn()
        |> infer_path(:bounce_remove, bounce.bounce_id)
        |> set_session(session)
        |> put_body(url_params)
        |> execute()

      assert_empty_response conn
      request_id = get_request_id(conn)

      [bounce_removed_event] = wait_events [:bounce_removed]

      assert bounce_removed_event.meta.request_id == request_id
      assert bounce_removed_event.domain == "account"
      assert bounce_removed_event.domain_id == to_string(entity.entity_id)

      assert bounce_removed_event.data.bounce_id == to_string(bounce.bounce_id)

      # Removed the bounce
      refute BounceQuery.fetch(bounce.bounce_id)
    end

    test "rejects when player is not the owner of the bounce" do
      session = SessionSetup.create_local!()

      # Bounce belongs to someone else
      {bounce, _} = NetworkSetup.Bounce.bounce()

      url_params = %{"bounce_id" => to_string(bounce.bounce_id)}

      conn =
        conn()
        |> infer_path(:bounce_remove, bounce.bounce_id)
        |> set_session(session)
        |> put_body(url_params)
        |> execute()

      assert_resp_error conn, {:bounce, :not_belongs}, 403
    end
  end
end
