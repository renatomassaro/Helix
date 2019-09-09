defmodule Helix.Account.Request.Register do

  use Helix.Webserver.Request

  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Webserver.CSRF, as: CSRFWeb
  alias Helix.Account.Henforcer.Account, as: AccountHenforcer
  alias Helix.Account.Public.Account, as: AccountPublic
  alias Helix.Account.Query.Account, as: AccountQuery

  def check_params(request, _session) do
    with \
      {:ok, username} <- validate_input(request.unsafe["username"], :username),
      {:ok, password} <-
        validate_input(request.unsafe["password"], :account_password),
      {:ok, email} <- validate_input(request.unsafe["email"], :email)
    do
      params = %{username: username, password: password, email: email}
      reply_ok(request, params: params)
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, _session) do
    username = request.params.username
    password = request.params.password
    email = request.params.email

    case AccountHenforcer.can_create_account?(username, password, email) do
      {true, _relay} ->
        reply_ok(request)

      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, _session) do
    username = request.params.username
    password = request.params.password
    email = request.params.email

    with \
      {:ok, account} <- AccountPublic.create(username, password, email),
      {:ok, session} <- SessionAction.create_unsynced(account),
      csrf_token = CSRFWeb.generate_token(session.session_id)
    do
      request
      |> create_session(session.session_id)
      |> reply_ok(meta: %{account: account, csrf_token: csrf_token})
    else
      {:error, reason} when is_atom(reason) ->
        internal_error(request, reason)

      {:error, _} ->
        internal_error(request)
    end
  end

  def render_response(request, session) do
    account_id = request.meta.account.account_id
    csrf_token = request.meta.csrf_token

    respond_ok(request, %{account_id: account_id, csrf_token: csrf_token})
  end
end
