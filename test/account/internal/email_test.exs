defmodule Helix.Account.Internal.EmailTest do

  use Helix.Test.Case.Integration

  alias Helix.Account.Internal.Email, as: EmailInternal

  alias Helix.Test.Account.Helper, as: AccountHelper
  alias Helix.Test.Account.Setup, as: AccountSetup

  describe "create_verification/1" do
    test "inserts the verification on the database" do
      account = AccountSetup.account!()

      assert {:ok, verification} = EmailInternal.create_verification(account)

      assert verification.account_id == account.account_id
      assert is_binary(verification.key)
      assert String.length(verification.key) == 6
    end
  end

  describe "fetch_verification_by_key/1" do
    test "returns the verification object when key exists" do
      {email_verification, %{account: account}} =
        AccountSetup.Email.email_verification()

      retrieved_verification =
        EmailInternal.fetch_verification_by_key(email_verification.key)

      assert retrieved_verification.key == email_verification.key
      assert retrieved_verification.account_id == account.account_id
      assert retrieved_verification.account == account
    end

    test "returns nil when key does not exist" do
      key = AccountHelper.Email.verification_key()
      refute EmailInternal.fetch_verification_by_key(key)
    end
  end
end
