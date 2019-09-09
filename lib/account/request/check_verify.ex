defmodule Helix.Account.Request.CheckVerify do

  use Helix.Webserver.Request

  alias Helix.Account.Model.Account
  alias Helix.Account.Query.Account, as: AccountQuery

  def check_params(request, _session),
    do: reply_ok(request)

  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, session) do
    account_id = session.context.account_id

    with \
      account = %Account{} <- AccountQuery.fetch(account_id),
      true <- account.verified
    do
      reply_ok(request)
    else
      false ->
        not_found(request, :not_verified)

      nil ->
        forbidden(request, :invalid_session)
    end
  end

  def render_response(request, _session),
    do: respond_empty(request)
end
