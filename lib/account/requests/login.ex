defmodule Helix.Account.Requests.Login do

  import Helix.Webserver.Utils

  alias Helix.Core.Validator

  def check_params(request, socket) do
    with \
      {:ok, username} <-
        Validator.validate_input(request.unsafe["username"], :username),
      {:ok, password} <-
        Validator.validate_input(request.unsafe["password"], :password)
    do
      reply_ok(request, %{params: %{username: username, password: password}})
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, socket) do
    reply_ok(request, %{meta: %{foo: :deu}})
  end

  def handle_request(request, socket) do
    reply_ok(request)
  end

  def render_response(request, socket) do
    respond_ok(request, %{mapa: :vazio})
  end
end
