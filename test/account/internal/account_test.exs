defmodule Helix.Account.Internal.AccountTest do

  use Helix.Test.Case.Integration

  alias Comeonin.Bcrypt
  alias Helix.Account.Internal.Account, as: AccountInternal
  alias Helix.Account.Internal.Email, as: EmailInternal
  alias Helix.Account.Internal.Document, as: DocumentInternal
  alias Helix.Account.Model.Account
  alias Helix.Account.Model.AccountSetting
  alias Helix.Account.Repo

  alias HELL.TestHelper.Random
  alias Helix.Test.Cache.Helper, as: CacheHelper
  alias Helix.Test.Account.Helper, as: AccountHelper
  alias Helix.Test.Account.Setup, as: AccountSetup

  defp params do
    %{
      username: Random.username(),
      email: Burette.Internet.email(),
      password: Burette.Internet.password()
    }
  end

  describe "creation" do
    test "succeeds with valid params" do
      params = %{
        username: Random.username(),
        email: Random.email(),
        password: Random.password()
      }

      assert {:ok, _} = AccountInternal.create(params)

      CacheHelper.sync_test()
    end

    test "fails when email is already in use" do
      {account, _} = AccountSetup.account()
      params = %{params()| email: account.email}

      assert {:error, changeset} = AccountInternal.create(params)
      assert :email in Keyword.keys(changeset.errors)
    end

    test "fails when username is already in use" do
      {account, _} = AccountSetup.account()
      params = %{params()| username: account.username}

      assert {:error, changeset} = AccountInternal.create(params)
      assert :username in Keyword.keys(changeset.errors)
    end

    test "fails when password is too short" do
      params = %{params()| password: "123"}

      assert {:error, changeset} = AccountInternal.create(params)
      assert :password in Keyword.keys(changeset.errors)
    end
  end

  describe "fetching" do
    test "succeeds by id" do
      {account, _} = AccountSetup.account()
      assert %Account{} = AccountInternal.fetch(account.account_id)
    end

    test "succeeds by email" do
      {account, _} = AccountSetup.account()
      assert %Account{} = AccountInternal.fetch_by_email(account.email)
    end

    test "succeeds by username" do
      {account, _} = AccountSetup.account()
      assert %Account{} = AccountInternal.fetch_by_username(account.username)
    end

    test "fails when account with id doesn't exist" do
      refute AccountInternal.fetch(AccountHelper.id())
    end

    test "fails when account with email doesn't exist" do
      refute AccountInternal.fetch_by_email(Random.email())
    end

    test "fails when account with username doesn't exist" do
      refute AccountInternal.fetch_by_username(Random.username())
    end
  end

  # describe "delete/1" do
  #   test "removes entry" do
  #     account = AccountSetup.account!()

  #     assert AccountInternal.fetch(account.account_id)

  #     AccountInternal.delete(account)

  #     refute AccountInternal.fetch(account.account_id)
  #   end
  # end

  describe "verify/2" do
    test "updates account status; removes verification entries" do
      {email_verification, %{account: account}} =
        AccountSetup.Email.email_verification()

      # Other entries that have been generated to the same account
      email_verification2 =
        AccountSetup.Email.email_verification!(account_id: account.account_id)
      email_verification3 =
        AccountSetup.Email.email_verification!(account_id: account.account_id)

      # Account is not verified
      refute account.verified

      assert {:ok, account} =
        AccountInternal.verify(account, email_verification)

      # Now the account has been verified!
      assert account.verified

      # All entries were deleted
      refute EmailInternal.fetch_verification_by_key(email_verification.key)
      refute EmailInternal.fetch_verification_by_key(email_verification2.key)
      refute EmailInternal.fetch_verification_by_key(email_verification3.key)
    end
  end

  describe "sign/3" do
    test "signs the document; updates account's document revision cache" do
      document_id = AccountHelper.Document.random_document()
      document_field =
        if document_id == :tos do
          :tos_revision
        else
          :pp_revision
        end

      account = AccountSetup.account!()
      account_id = account.account_id
      document = AccountHelper.Document.get_current(document_id)

      info = %{user_agent: "useragent", ip_address: "1.2.3.4"}

      # Account never signed this document revision
      refute Map.fetch!(account, document_field) == document.revision_id
      refute DocumentInternal.fetch_current_signature(account_id, document_id)

      assert {:ok, account} =
        AccountInternal.sign_document(account, document, info)

      # Now the account did sign the document
      assert Map.fetch!(account, document_field) == document.revision_id
      document_signature =
        DocumentInternal.fetch_current_signature(account_id, document_id)

      assert document_signature.account_id == account_id
      assert document_signature.document_id == document_id
      assert document_signature.revision_id == document.revision_id
      assert document_signature.user_agent == info.user_agent
      assert document_signature.ip_address == info.ip_address
      signature_date = document_signature.signature_date

      # Signature happened at most 1 second ago.
      # This is required because date is truncated in seconds, and the signature
      # may happen at 0.999ms while this check happens at 1.001ms
      assert DateTime.diff(signature_date, DateTime.utc_now()) >= -1
    end

    test "performs a noop when that same document has already been signed" do
      document_id = AccountHelper.Document.random_document()
      document_field =
        if document_id == :tos do
          :tos_revision
        else
          :pp_revision
        end

      account = AccountSetup.account!()
      account_id = account.account_id
      document = AccountHelper.Document.get_current(document_id)

      info = %{user_agent: "useragent", ip_address: "1.2.3.4"}

      # Not signed yet
      refute Map.fetch!(account, document_field) == document.revision_id
      refute DocumentInternal.fetch_current_signature(account_id, document_id)

      assert {:ok, account1} =
        AccountInternal.sign_document(account, document, info)

      # Signing for the first time
      assert Map.fetch!(account1, document_field) == document.revision_id
      assert DocumentInternal.fetch_current_signature(account_id, document_id)

      # Signing for the second time
      assert {:ok, account2} =
        AccountInternal.sign_document(account1, document, info)

      # Nothing has changed
      assert account1 == account2
      assert Map.fetch!(account2, document_field) == document.revision_id
      assert DocumentInternal.fetch_current_signature(account_id, document_id)
    end

    test "blows up when signing an older version" do
      document_rev2 =
        AccountSetup.Document.document!(id: :tos, rev_id: 2, current?: true)
      document_rev3 =
        AccountSetup.Document.document!(id: :tos, rev_id: 3, current?: true)

      account = AccountSetup.account!()
      account_id = account.account_id
      info = %{user_agent: "useragent", ip_address: "1.2.3.4"}

      # Account signed rev 3
      assert {:ok, account} =
        AccountInternal.sign_document(account, document_rev3, info)
      assert DocumentInternal.fetch_signature(account_id, :tos, 3)

      # Bad things will happen if account attempts to sign rev 2
      assert {:error, _} =
        AccountInternal.sign_document(account, document_rev2, info)

      AccountHelper.Document.reset_db()
    end
  end

  describe "account updating" do
    test "changes its fields" do
      account = AccountSetup.account!()
      params = %{
        email: Random.email(),
        password: Random.password(),
        verified: true
      }

      {:ok, updated_account} = AccountInternal.update(account, params)

      assert params.email == updated_account.email
      assert Bcrypt.checkpw(params.password, updated_account.password)
      assert params.verified == updated_account.verified
    end

    test "fails when email is already in use" do
      account1 = AccountSetup.account!()
      account2 = AccountSetup.account!()

      params = %{email: account1.email}

      {:error, cs} = AccountInternal.update(account2, params)

      assert :email in Keyword.keys(cs.errors)
    end
  end

  describe "putting settings" do
    test "succeeds with valid params" do
      account = AccountSetup.account!()
      settings = %{is_beta: true}

      AccountInternal.put_settings(account, settings)
      %{settings: got} = Repo.get(AccountSetting, account.account_id)

      assert settings == Map.from_struct(got)
    end

    test "fails with contract violating params" do
      account = AccountSetup.account!()
      bogus = %{is_beta: "uhe"}
      result = AccountInternal.put_settings(account, bogus)

      assert {:error, _} = result
    end
  end

  describe "getting settings" do
    @tag :pending
    test "includes modified settings" do
      # defaults =
      #   %Setting{}
      #   |> Map.from_struct()
      #   |> MapSet.new()

      # custom_keys = fn settings ->
      #   settings
      #   |> Map.from_struct()
      #   |> Enum.reject(&MapSet.member?(defaults, &1))
      #   |> Keyword.keys()
      # end

      # %{account: account, settings: settings} =
      #   Factory.insert(:account_setting)

      # result =
      #   account
      #   |> AccountInternal.get_settings()
      #   |> custom_keys.()

      # assert custom_keys.(settings) == result
    end
  end
end
