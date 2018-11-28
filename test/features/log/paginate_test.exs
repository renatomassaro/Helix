defmodule Helix.Test.Features.Log.Paginate do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  alias Helix.Test.Log.Setup, as: LogSetup

  @moduletag :feature

  describe "log recover" do
    test "Fetches logs older than `log_id`" do
      %{local: %{gateway: gateway}, session: session} =
        SessionSetup.create_local()

      log1 =
        LogSetup.log!(
          log_id: "e3ac:6eef:c924:a009:3f17:1abd:d5d8:5809",
          server_id: gateway.server_id
        )

      log2 =
        LogSetup.log!(
          log_id: "e3ac:6eef:c924:a009:3f17:2a9f:9983:8709",
          server_id: gateway.server_id
        )

      log3 =
        LogSetup.log!(
          log_id: "e3ac:6eef:c924:a009:3f17:3a43:a825:4009",
          server_id: gateway.server_id
        )

      # We'll use `log2` as starting point, so `log1` and `log2` should not be
      # fetched.
      params = %{"log_id" => to_string(log2.log_id)}

      base_conn =
        conn()
        |> infer_path(:log_paginate, [gateway.server_id])
        |> set_session(session)

      conn =
        base_conn
        |> put_body(params)
        |> execute()

      assert_status conn, 200

      logs = get_response(conn)

      # Only one log was returned...
      assert length(logs) == 1

      # And it is `log3`
      assert List.first(logs).log_id == to_string(log3.log_id)

      # Let's try again, with `log1` as the starting point

      params = %{"log_id" => to_string(log1.log_id)}
      conn =
        base_conn
        |> put_body(params)
        |> execute()

      assert_status conn, 200

      logs = get_response(conn)

      # Two log were returned...
      assert length(logs) == 2

      # And they are `log2` and `log3`
      assert List.first(logs).log_id == to_string(log2.log_id)
      assert List.last(logs).log_id == to_string(log3.log_id)
    end
  end
end
