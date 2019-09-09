defmodule Helix.Account.Henforcer.DocumentTest do

  use Helix.Test.Case.Integration

  import Helix.Test.Henforcer.Macros

  alias HELL.DateUtils
  alias Helix.Account.Model.Document
  alias Helix.Account.Henforcer.Document, as: DocumentHenforcer
  alias Helix.Account.Query.Document, as: DocumentQuery

  alias Helix.Test.Account.Helper, as: AccountHelper
  alias Helix.Test.Account.Setup, as: AccountSetup

  describe "document_exists?/1" do
    test "accepts when document exists" do
      # Initial version of the documents are added with Helix Seeds, so we dont
      # need to create them
      assert {true, relay_tos} = DocumentHenforcer.document_exists?(:tos, 1)
      assert {true, relay_pp} = DocumentHenforcer.document_exists?(:pp, 1)

      assert_relay relay_tos, [:document]
      assert_relay relay_pp, [:document]
      assert relay_tos.document.document_id == :tos
      assert relay_pp.document.document_id == :pp
    end

    test "rejects when document doesnt exists" do
      assert {false, reason1, _} = DocumentHenforcer.document_exists?(:tos, 2)
      assert {false, reason2, _} = DocumentHenforcer.document_exists?(:pp, 0)

      assert reason1 == {:document, :not_exists}
      assert reason2 == reason1

      # `:nope` is invalid type (since we use an Enum for document id).
      # This is a non-sense scenario, just added here for documentation
      # If somehow the document id is invalid, the henforcer would do its job
      # (by blowing up)
      assert_raise Ecto.Query.CastError, fn ->
        DocumentHenforcer.document_exists?(:nope, 1)
      end
    end
  end

  describe "document_signable?/1" do
    test "accepts when document is the current one" do
      document = DocumentQuery.fetch(:tos, 1)

      # This document is current
      assert document.current

      assert {true, relay} = DocumentHenforcer.document_signable?(document)
      assert_relay relay, [:document]
      assert relay.document == document
    end

    test "accepts when document is not the current one but not yet enforced" do
      opts = [id: :tos, rev_id: 2, current?: false, enforced?: false]
      document = AccountSetup.Document.document!(opts)

      # Document is not current
      refute document.current

      # But it is not expired!
      refute Document.expired?(document)

      assert {true, relay} = DocumentHenforcer.document_signable?(document)
      assert_relay relay, [:document]
      assert relay.document == document

      AccountHelper.Document.reset_db()
    end

    test "rejects on all other cases" do
      opts = [
        id: :tos,
        rev_id: 2,
        current?: false,
        enforced?: true,
        enforced_until: DateUtils.date_before(60)
      ]
      document = AccountSetup.Document.document!(opts)

      # Document is expired
      assert Document.expired?(document)

      assert {false, reason, _} = DocumentHenforcer.document_signable?(document)
      assert reason == {:document, :not_signable}

      AccountHelper.Document.reset_db()
    end
  end
end
