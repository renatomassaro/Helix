defmodule Helix.Account.Request.RegisterTest do

  use Helix.Test.Case.Integration

  alias Helix.Account.Request.Register, as: RegisterRequest
  alias Helix.Account.Query.Account, as: AccountQuery

  alias Helix.Test.Session.Setup, as: SessionSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Account.Helper, as: AccountHelper
  alias Helix.Test.Account.Setup, as: AccountSetup

  describe "check_params/2" do
    test "validates expected data" do
      username = AccountHelper.username()
      password = AccountHelper.password()
      email = AccountHelper.email()

      # Valid entries
      p0 = %{
        "username" => username,
        "password" => password,
        "email" => email
      }

      r0 = RequestHelper.mock_request(unsafe: p0)
      assert {:ok, request} = RegisterRequest.check_params(r0, {})

      assert request.params.username == username
      assert request.params.password == password
      assert request.params.email == email
    end

    test "rejects invalid input" do
      session = {}
      valid_username = AccountHelper.username()
      valid_password = AccountHelper.password()
      valid_email = AccountHelper.email()

      p0 = %{
        "username" => "pg",
        "password" => valid_password,
        "email" => valid_email
      }

      p1 = %{
        "username" => "IamTooLongOver15",
        "password" => valid_password,
        "email" => valid_email
      }

      p2 = %{
        "username" => "Invalid Char",
        "password" => valid_password,
        "email" => valid_email
      }

      p3 = %{
        "username" => "Inv$ldi",
        "password" => valid_password,
        "email" => valid_email
      }

      p4 = %{
        "username" => valid_username,
        "password" => "small",
        "email" => valid_email
      }

      p5 = %{
        "username" => valid_username,
        "password" => valid_password,
        "email" =>  "ab"
      }

      p6 = %{
        "username" => valid_username,
        "password" => valid_password,
        "email" =>  "IHaveNoAtSigns"
      }

      r0 = RequestHelper.mock_request(unsafe: p0)
      r1 = RequestHelper.mock_request(unsafe: p1)
      r2 = RequestHelper.mock_request(unsafe: p2)
      r3 = RequestHelper.mock_request(unsafe: p3)
      r4 = RequestHelper.mock_request(unsafe: p4)
      r5 = RequestHelper.mock_request(unsafe: p5)
      r6 = RequestHelper.mock_request(unsafe: p6)

      assert {:error, _, err0} = RegisterRequest.check_params(r0, session)
      assert {:error, _, err1} = RegisterRequest.check_params(r1, session)
      assert {:error, _, err2} = RegisterRequest.check_params(r2, session)
      assert {:error, _, err3} = RegisterRequest.check_params(r3, session)
      assert {:error, _, err4} = RegisterRequest.check_params(r4, session)
      assert {:error, _, err5} = RegisterRequest.check_params(r5, session)
      assert {:error, _, err6} = RegisterRequest.check_params(r6, session)

      assert err0 == :bad_request
      assert err1 == err2
      assert err2 == err3
      assert err4 == err5
      assert err6 == err5
    end
  end

  describe "check_permissions/2" do
    test "accepts when all is fine" do
      p0 = %{
        "username" => AccountHelper.username(),
        "password" => AccountHelper.password(),
        "email" => AccountHelper.email()
      }

      r0 = RequestHelper.mock_request(unsafe: p0)
      assert {:ok, _request} =
        RequestHelper.check_permissions(RegisterRequest, r0, {})
    end

    test "rejects when account or email are already taken" do
      taken_account = AccountSetup.account!()

      p0 = %{
        "username" => taken_account.username,
        "password" => AccountHelper.password(),
        "email" => AccountHelper.email()
      }

      p1 = %{
        "username" => AccountHelper.username,
        "password" => AccountHelper.password(),
        "email" => taken_account.email
      }

      r0 = RequestHelper.mock_request(unsafe: p0)
      r1 = RequestHelper.mock_request(unsafe: p1)

      assert {:error, _, err0} =
        RequestHelper.check_permissions(RegisterRequest, r0, {})
      assert {:error, _, err1} =
        RequestHelper.check_permissions(RegisterRequest, r1, {})

      assert err0 == :username_taken
      assert err1 == :email_taken
    end

    test "rejects when password is the same as the username" do
      p0 = %{
        "username" => "ThisIsMyUser",
        "password" => "ThisIsMyUser",
        "email" => AccountHelper.email()
      }

      r0 = RequestHelper.mock_request(unsafe: p0)
      assert {:error, _, reason} =
        RequestHelper.check_permissions(RegisterRequest, r0, {})

      assert reason == :password_insecure
    end
  end

  describe "handle_request/2" do
    test "account is created" do
      username = AccountHelper.username()
      password = AccountHelper.password()
      email = AccountHelper.email()

      p0 = %{
        "username" => username,
        "password" => password,
        "email" => email
      }

      r0 = RequestHelper.mock_request(unsafe: p0)
      assert {:ok, request} =
        RequestHelper.handle_request(RegisterRequest, r0, {})

      account_id = request.meta.account.account_id

      created_account = AccountQuery.fetch(account_id)

      # Created account with the correct data
      assert created_account.username == username
      assert created_account.email == email

      # The password on the database is not the same as the request, since
      # the request one is plaintext and the database one is hashed.
      refute created_account.password == password

      # Account is not verified
      refute created_account.verified

      # Generated email verification code, added to queue
      # TODO

      # Returned a csrf token
      assert is_binary(request.meta.csrf_token)
    end
  end
end

