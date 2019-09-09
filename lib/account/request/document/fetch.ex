defmodule Helix.Account.Request.Document.Fetch do

  use Helix.Webserver.Request

  alias Helix.Account.Query.Document, as: DocumentQuery

  def check_params(request, _session) do
    document_id =
      case request.conn.path_info do
        [_, "document", "tos"] ->
          :tos

        [_, "document", "pp"] ->
          :pp
      end

    type =
      case request.unsafe["type"] do
        "html" ->
          :html

        "text" ->
          :raw

        _ ->
          :raw
      end

    reply_ok(request, params: %{document_id: document_id, type: type})
  end

  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, _session) do
    document = DocumentQuery.fetch_current(request.params.document_id)

    reply_ok(request, meta: %{document: document})
  end

  def render_response(request, _session) do
    type = request.params.type
    document = request.meta.document

    {content, diff} =
      if type == :html do
        {document.content_html, document.diff_html}
      else
        {document.content_raw, document.diff_raw}
      end

    data = %{
      content: content,
      diff: diff,
      update_reason: document.update_reason,
      revision_id: document.revision_id
    }

    respond_ok(request, data)
  end
end
