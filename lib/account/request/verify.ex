defmodule Helix.Account.Request.Verify do

  use Helix.Webserver.Request

  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Webserver.CSRF, as: CSRFWeb
  alias Helix.Account.Model.Account
  alias Helix.Account.Public.Account, as: AccountPublic
  alias Helix.Account.Query.Account, as: AccountQuery

  def check_params(request, _session) do
    with \
      {:ok, verification_key} <-
        validate_input(request.unsafe["verification_key"], :verification_key),
      unsafe_with_login? = input_optional(request, "with_login", false),
      {:ok, with_login?} <- ensure_type(:bool, unsafe_with_login?)
    do
      params = %{verification_key: verification_key, with_login?: with_login?}
      reply_ok(request, params: params)
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, _session) do
    verification_key = request.params.verification_key
    with_login? = request.params.with_login?

    # Sleep on purpose
    :timer.sleep(1000)

    if request.params.with_login? do
      handle_request_login(request, verification_key)
    else
      handle_request_simple(request, verification_key)
    end
  end

  def render_response(request, _session) do
    account = request.meta.account

    if request.params.with_login? do
      data = %{
        account_id: to_string(account.account_id),
        username: account.username,
        csrf_token: request.meta.csrf_token
      }

      respond_ok(request, data)
    else
      respond_empty(request)
    end
  end

  defp handle_request_login(request, verification_key) do
    with \
      {:ok, account} <- AccountPublic.verify(verification_key),
      {:ok, session} <- SessionAction.create_unsynced(account),
      csrf_token = CSRFWeb.generate_token(session.session_id)
    do
      request
      |> create_session(session.session_id)
      |> reply_ok(meta: %{account: account, csrf_token: csrf_token})
    else
      {:error, :wrong_key} ->
        not_found(request, :wrong_key)
    end
  end

  defp handle_request_simple(request, verification_key) do
    case AccountPublic.verify(verification_key) do
      {:ok, account} ->
        reply_ok(request, meta: %{account: account})

      {:error, :wrong_key} ->
        not_found(request, :wrong_key)
    end
  end
end
