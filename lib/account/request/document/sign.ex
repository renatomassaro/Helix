defmodule Helix.Account.Request.Document.Sign do

  use Helix.Webserver.Request

  alias Helix.Account.Model.Account
  alias Helix.Account.Model.Document
  alias Helix.Account.Henforcer.Account, as: AccountHenforcer
  alias Helix.Account.Henforcer.Document, as: DocumentHenforcer
  alias Helix.Account.Public.Account, as: AccountPublic

  def check_params(request, session) do
    document_id =
      case request.conn.path_info do
        [_, "document", "tos", "sign"] ->
          :tos

        [_, "document", "pp", "sign"] ->
          :pp
      end

    with \
      {:ok, revision_id} <-
        ensure_type(:integer, request.unsafe["revision_id"]),
      true <- revision_id > 0
    do
      params = %{
        document_id: document_id,
        revision_id: revision_id,
        user_agent: fetch_user_agent(request),
        ip_address: fetch_client_ip(request)
      }

      reply_ok(request, params: params)
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    account_id = session.context.account_id
    document_id = request.params.document_id
    revision_id = request.params.revision_id

    document_tuple = {document_id, revision_id}
    with \
      {true, r1} <-
        AccountHenforcer.can_sign_document?(account_id, document_tuple),
      account = r1.account,
      {true, r2} <-
        DocumentHenforcer.can_sign_document?(account, document_tuple),
      document = r2.document
    do
      reply_ok(request, meta: %{account: account, document: document})
    else
      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, session) do
    account = request.meta.account
    document = request.meta.document
    info = %{
      user_agent: request.params.user_agent,
      ip_address: request.params.ip_address
    }

    case AccountPublic.sign_document(account, document, info) do
      {:ok, _} ->
        reply_ok(request)

      {:error, _} ->
        internal_error(request)
    end
  end

  def render_response(request, session),
    do: respond_empty(request)
end
