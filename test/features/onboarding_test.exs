defmodule Helix.Test.Features.Onboarding do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  alias Helix.Account.Query.Account, as: AccountQuery
  alias Helix.Account.Query.Document, as: DocumentQuery

  alias Helix.Test.Account.Helper, as: AccountHelper
  alias Helix.Test.Account.Setup, as: AccountSetup

  describe "user onboarding" do
    test "account registration" do
      username = AccountHelper.username()
      password = AccountHelper.password()
      email = AccountHelper.email()

      params =
        %{
          "username" => username,
          "password" => password,
          "email" => email
        }

      conn =
        conn()
        |> infer_path(:account_register, [])
        |> put_body(params)
        |> execute()

      assert_status conn, 200

      # Response comes with session cookie
      refute Enum.empty?(conn.resp_cookies)

      # Account was indeed created
      account_id = conn.assigns.helix_response.account_id
      account = AccountQuery.fetch(account_id)

      assert account.username == username
      assert account.email == email
      refute account.password == password

      # TODO: EmailVerification was sent
    end
  end

  describe "CheckUsername request" do
    test "works as expected" do
      params = %{"username" => "phoebe"}

      base_conn =
        conn()
        |> infer_path(:account_check_username, [])
        |> put_body(params)

      assert_status execute(base_conn), 200

      # Now we'll add the user `phoebe`. The request above should return 403

      AccountSetup.account!(username: "phoebe")

      assert_status execute(base_conn), 403
    end
  end

  describe "CheckEmail request" do
    test "works as expected" do
      params = %{"email" => "phoebe@the.dog"}

      base_conn =
        conn()
        |> infer_path(:account_check_email, [])
        |> put_body(params)

      assert_status execute(base_conn), 200

      # Now we'll add the user `phoebe`. The request above should return 403

      AccountSetup.account!(email: "phoebe@the.dog")

      assert_status execute(base_conn), 403
    end
  end

  describe "Sign request" do
    test "fetches the requested documents" do
      params = %{"type" => "html"}

      conn_tos =
        conn()
        |> infer_path(:document_fetch_tos, [])
        |> put_body(params)
        |> execute()

      conn_pp =
        conn()
        |> infer_path(:document_fetch_pp, [])
        |> put_body(params)
        |> execute()

      assert_status conn_tos, 200
      assert is_binary(conn_tos.assigns.helix_response.content)
      assert is_binary(conn_tos.assigns.helix_response.diff)
      assert is_binary(conn_tos.assigns.helix_response.update_reason)
      assert is_integer(conn_tos.assigns.helix_response.revision_id)

      assert_status conn_pp, 200
      assert is_binary(conn_pp.assigns.helix_response.content)
      assert is_binary(conn_pp.assigns.helix_response.diff)
      assert is_binary(conn_pp.assigns.helix_response.update_reason)
      assert is_integer(conn_pp.assigns.helix_response.revision_id)
    end

    test "Signs the given documents" do
      document_tos = AccountHelper.Document.get_current(:tos)
      document_pp = AccountHelper.Document.get_current(:pp)

      params = %{"revision_id" => 1}

      {session, %{account: account}} = SessionSetup.create_unsynced()

      # All unsigned
      refute DocumentQuery.fetch_current_signature(account.account_id, :tos)
      refute DocumentQuery.fetch_current_signature(account.account_id, :pp)

      conn_tos =
        conn()
        |> infer_path(:document_sign_tos, [])
        |> set_session(session)
        |> put_body(params)
        |> execute()

      conn_pp =
        conn()
        |> infer_path(:document_sign_pp, [])
        |> set_session(session)
        |> put_body(params)
        |> execute()

      # All signed!
      assert DocumentQuery.fetch_current_signature(account.account_id, :tos)
      assert DocumentQuery.fetch_current_signature(account.account_id, :pp)
    end
  end
end


    # test "initial player stuff was generated properly" do
    #   email = Random.email()
    #   username = Random.username()
    #   password = Random.password()

    #   # Create the account
    #   # TODO: Use Phoenix endpoint for full integration test. Can't do it now
    #   # since public registrations are closed
    #   assert {:ok, account} = AccountFlow.create(email, username, password)

    #   # Corresponding entity was created
    #   entity =
    #     account.account_id
    #     |> EntityQuery.get_entity_id()
    #     |> EntityQuery.fetch()

    #   assert entity.entity_type == :account

    #   # Player's initial servers were created
    #   assert [story_server_id, server_id] = EntityQuery.get_servers(entity)

    #   server = ServerQuery.fetch(server_id)
    #   story_server = ServerQuery.fetch(story_server_id)

    #   # Both servers have a valid motherboard attached to it
    #   assert server.motherboard_id
    #   assert story_server.motherboard_id

    #   # One of the servers is for the story...
    #   assert server.type == :desktop
    #   assert story_server.type == :desktop_story

    #   # Tutorial mission was created
    #   assert [%{object: step}] = StoryQuery.get_steps(entity.entity_id)
    #   assert step.name == Step.first_step_name()
    # end
