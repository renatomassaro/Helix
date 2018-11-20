defmodule Helix.Account.Requests.Login do

  import Helix.Webserver.Utils

  alias Helix.Core.Validator
  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Webserver.CSRF, as: CSRFWeb
  alias Helix.Account.Query.Account, as: AccountQuery

  def check_params(request, _session) do
    with \
      {:ok, username} <-
        Validator.validate_input(request.unsafe["username"], :username),
      {:ok, password} <-
        Validator.validate_input(request.unsafe["password"], :password)
    do
      params = %{username: username, password: password}
      reply_ok(request, params: params)
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, _session) do
    username = request.params.username
    password = request.params.password

    with \
      account = %_{} <- AccountQuery.fetch_by_credential(username, password),
      {:ok, session} <- SessionAction.create_unsynced(account),
      csrf_token = CSRFWeb.generate_token(session.session_id)
    do
      request
      |> create_session(session.session_id)
      |> reply_ok(meta: %{account: account, csrf_token: csrf_token})
    else
      nil ->
        not_found(request)

      {:error, :internal} ->
        internal_error(request)
    end
  end

  def render_response(request, session) do
    account_id = request.meta.account.account_id
    csrf_token = request.meta.csrf_token

    respond_ok(request, %{account_id: account_id, csrf_token: csrf_token})
  end
end
