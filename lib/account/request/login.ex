defmodule Helix.Account.Request.Login do

  use Helix.Webserver.Request

  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Webserver.CSRF, as: CSRFWeb
  alias Helix.Account.Model.Account
  alias Helix.Account.Query.Account, as: AccountQuery

  def check_params(request, _session) do
    with \
      {:ok, username} <- validate_input(request.unsafe["username"], :username),
      {:ok, password} <-
        validate_input(request.unsafe["password"], :account_password)
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
    setup_status = get_setup_status(request.meta.account)

    data = %{
      account_id: account_id,
      csrf_token: csrf_token,
      setup_status: setup_status
    }

    respond_ok(request, data)
  end

  defp get_setup_status(%Account{verified: false}),
    do: :unverified
  defp get_setup_status(%Account{tos_revision: 0}),
    do: :missing_signature_tos
  defp get_setup_status(%Account{pp_revision: 0}),
    do: :missing_signature_pp
  defp get_setup_status(_),
    do: :ok
end
