defmodule Helix.Account.Henforcer.Document do

  import Helix.Henforcer

  alias Helix.Account.Model.Account
  alias Helix.Account.Model.Document
  alias Helix.Account.Query.Document, as: DocumentQuery

  @type document_exists_relay :: %{document: Document.t}
  @type document_exists_relay_partial :: %{}
  @type document_exists_error ::
    {false, {:document, :not_exists}, document_exists_relay_partial}

  @spec document_exists?(Document.id, Document.revision_id) ::
    {true, document_exists_relay}
    | {false, {:document, :not_exists}, document_exists_relay_partial}
  def document_exists?(document_id, revision_id) do
    with doc = %Document{} <- DocumentQuery.fetch(document_id, revision_id) do
      reply_ok(%{document: doc})
    else
      _ ->
        reply_error({:document, :not_exists})
    end
  end

  @type document_current_relay :: %{document: Document.t}
  @type document_current_relay_partial :: document_current_relay
  @type document_current_error ::
    {false, {:document, :not_signable}, document_current_relay_partial}

  @spec document_current?(Document.t) ::
    {true, document_current_relay}
    | document_current_error
  def document_current?(document = %Document{current: current?}) do
    if current? do
      reply_ok()
    else
      reply_error({:document, :not_current})
    end
    |> wrap_relay(%{document: document})
  end

  @type document_signable_relay :: %{document: Document.t}
  @type document_signable_relay_partial :: document_signable_relay
  @type document_signable_error ::
    {false, {:document, :not_signable}, document_signable_relay_partial}
    | document_current_error

  @spec document_signable?(Document.t) ::
    {true, document_signable_relay}
    | document_signable_error
  @doc """
  A document is signable (can be signed) when it is current or newer than
  current. A document that is not current may be signed when:
  1) A new revision of the document is published
  2) This revision is not effective (enforced) yet - it will be in X days.
  3) Users are prompted to read and sign the revision, with the option to either
    - sign now; or
    - sign later.
  4) If "sign later" is selected, the user is prompted on each login and may
    keep selecting "sign later" while the `enforced_from` is in a future date.
    If the new revision starts being enforced, the user MUST sign in order to
    keep playing the game.
  """
  def document_signable?(document) do
    case document_current?(document) do
      yes_it_is_current = {true, _} ->
        yes_it_is_current

      {false, {:document, :not_current}, _} ->
        unless Document.expired?(document) do
          reply_ok()
        else
          reply_error({:document, :not_signable})
        end
        |> wrap_relay(%{document: document})
    end
  end

  @type can_sign_document_relay :: %{document: Document.t}
  @type can_sign_document_relay_partial :: can_sign_document_relay
  @type can_sign_document_error ::
    document_exists_error
    | document_signable_error

  @spec can_sign_document?(Account.t, {Document.id, Document.revision_id}) ::
    {true, can_sign_document_relay}
    | can_sign_document_error
  def can_sign_document?(account = %Account{}, {document_id, revision_id}) do
    with \
      {true, r1} <- document_exists?(document_id, revision_id),
      document = r1.document,
      {true, _} <- document_signable?(document)
    do
      reply_ok(r1)
    end
  end
end
