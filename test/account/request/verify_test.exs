defmodule Helix.Account.Request.VerifyTest do

  use Helix.Test.Case.Integration

  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Account.Request.Verify, as: VerifyRequest
  alias Helix.Account.Query.Account, as: AccountQuery
  alias Helix.Account.Query.Email, as: EmailQuery

  alias Helix.Test.Session.Setup, as: SessionSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Account.Helper, as: AccountHelper
  alias Helix.Test.Account.Setup, as: AccountSetup

  describe "check_params/2" do
    test "validates expected data" do
      verification_key = AccountHelper.Email.verification_key()
      p0 = %{"verification_key" => verification_key}
      p1 = %{
        "verification_key" => verification_key,
        "with_login" => true
      }

      r0 = RequestHelper.mock_request(unsafe: p0)
      r1 = RequestHelper.mock_request(unsafe: p1)

      assert {:ok, req0} = VerifyRequest.check_params(r0, {})
      assert {:ok, req1} = VerifyRequest.check_params(r1, {})

      assert req0.params.verification_key == verification_key
      refute req0.params.with_login?
      assert req1.params.verification_key == verification_key
      assert req1.params.with_login?
    end

    test "rejects invalid data" do
      valid_key = AccountHelper.Email.verification_key()

      p0 = %{"verification_key" => "#$#$#$"}
      p1 = %{"verification_key" => nil}
      p2 = %{"verification_key" => [1, 2]}
      p3 = %{"with_login" => true}
      p4 = %{"verification_key" => valid_key, "with_login" => "wut"}

      all_params = [p0, p1, p2, p3, p4]

      Enum.each(all_params, fn params ->
        req = RequestHelper.mock_request(unsafe: params)
        assert {:error, _, reason} = VerifyRequest.check_params(req, {})
        assert reason == :bad_request
      end)
    end
  end

  describe "handle_request/2" do
    test "verifies the account and logs in (when requested)" do
      {email_verification, %{account: account}} =
        AccountSetup.Email.email_verification()

      # Before verification there is no entity
      refute EntityQuery.fetch(EntityQuery.get_entity_id(account))

      params =
        %{
          "verification_key" => email_verification.key,
          "with_login" => true
        }

      req = RequestHelper.mock_request(unsafe: params)
      assert {:ok, request} =
        RequestHelper.handle_request(VerifyRequest, req, {})

      assert request.meta.account.verified
      assert request.meta.account.account_id == account.account_id

      # Now the entity exists, which means account was verified. Q.E.D.
      assert EntityQuery.fetch(EntityQuery.get_entity_id(account))

      # Returned login information
      assert is_binary(request.meta.csrf_token)
      refute Enum.empty?(request.__special__)

      # Verification key was deleted from the database
      refute EmailQuery.fetch_verification_by_key(email_verification.key)
    end

    test "verifies the account and does not logs in (when not requested)" do
      {email_verification, %{account: account}} =
        AccountSetup.Email.email_verification()

      # Before verification there is no entity
      refute EntityQuery.fetch(EntityQuery.get_entity_id(account))

      params = %{"verification_key" => email_verification.key}

      req = RequestHelper.mock_request(unsafe: params)
      assert {:ok, request} =
        RequestHelper.handle_request(VerifyRequest, req, {})

      assert request.meta.account.verified
      assert request.meta.account.account_id == account.account_id

      # Now the entity exists, which means account was verified. Q.E.D.
      assert EntityQuery.fetch(EntityQuery.get_entity_id(account))

      # There are no login information
      refute Map.has_key?(request.meta, :crsf_token)
      assert Enum.empty?(request.__special__)

      # Verification key was deleted from the database
      refute EmailQuery.fetch_verification_by_key(email_verification.key)
    end

    test "does not verify twice" do
      {email_verification, %{account: account}} =
        AccountSetup.Email.email_verification()

      params = %{"verification_key" => email_verification.key}

      # First verification, it works
      req = RequestHelper.mock_request(unsafe: params)
      assert {:ok, request} =
        RequestHelper.handle_request(VerifyRequest, req, {})

      # Second verification
      assert {:error, _, reason} =
        RequestHelper.handle_request(VerifyRequest, req, {})

      assert reason == :wrong_key
    end

    test "rejects if verification key is wrong / not found" do
      params = %{"verification_key" => AccountHelper.Email.verification_key()}
      req = RequestHelper.mock_request(unsafe: params)

      assert {:error, _, reason} =
        RequestHelper.handle_request(VerifyRequest, req, {})

      assert reason == :wrong_key
    end
  end
end
