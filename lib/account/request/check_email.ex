defmodule Helix.Account.Request.CheckEmail do

  use Helix.Webserver.Request

  alias Helix.Account.Model.Account
  alias Helix.Account.Query.Account, as: AccountQuery

  def check_params(request, _) do
    case validate_input(request.unsafe["email"], :email) do
      {:ok, email} ->
        reply_ok(request, params: %{email: email})

      _ ->
        respond_taken(request)
    end
  end

  def check_permissions(request, _),
    do: reply_ok(request)

  def handle_request(request, _) do
    case AccountQuery.fetch_by_email(request.params.email) do
      %Account{} ->
        respond_taken(request)

      nil ->
        reply_ok(request)
    end
  end

  def render_response(request, _),
    do: respond_empty(request)

  defp respond_taken(request),
    do: forbidden(request, :email_taken)
end
