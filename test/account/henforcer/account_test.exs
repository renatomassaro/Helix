defmodule Helix.Account.Henforcer.AccountTest do

  use Helix.Test.Case.Integration

  import Helix.Test.Henforcer.Macros

  alias Helix.Account.Henforcer.Account, as: AccountHenforcer

  alias Helix.Test.Account.Helper, as: AccountHelper
  alias Helix.Test.Account.Setup, as: AccountSetup

  describe "can_sign_document?/2" do
    test "accepts when use can sign document" do
      account = AccountSetup.account!()
      document = AccountHelper.Document.get_current()
      document_tuple = {document.document_id, document.revision_id}

      assert {true, relay} =
        AccountHenforcer.can_sign_document?(account.account_id, document_tuple)

      assert_relay relay, [:account]
      assert relay.account == account
    end

    test "reject when user already signed newer document" do
      account = AccountSetup.account!(tos_revision: 3)
      document = AccountSetup.Document.document!(id: :tos, rev_id: 2)
      document_tuple = {document.document_id, document.revision_id}

      # User wants to sign TOS revision 2
      assert document.document_id == :tos
      assert document.revision_id == 2

      # And user already signed TOS revision 3
      assert account.tos_revision == 3

      assert {false, reason, _} =
        AccountHenforcer.can_sign_document?(account.account_id, document_tuple)
      assert reason == {:signature, :stale_document}
    end
  end
end
