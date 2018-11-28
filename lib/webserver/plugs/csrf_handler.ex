defmodule Helix.Webserver.Plugs.CSRFHandler do

  import Plug.Conn
  import Helix.Webserver.Plugs.Utils

  alias Helix.Webserver.CSRF, as: CSRFWeb
  alias Helix.Webserver.Session, as: SessionWeb

  def init(opts),
    do: opts

  def call(conn, _opts) do
    cookie_session_id = SessionWeb.get_session_id(conn)
    csrf_token = CSRFWeb.get_csrf_token(conn)

    with \
      true <- CSRFWeb.requires_csrf?(conn.method, conn.path_info) || :exempt,
      # /\ Checks whether the requested page requires a CSRF token

      # There must exist a session (in the header) and a token (in the req body)
      true <- not is_nil(cookie_session_id) || :nxsession,
      true <- is_binary(csrf_token) || :nxtoken,

      # Decrypt the CSRF token
      {:ok, token_session_id} <- CSRFWeb.validate_token(csrf_token),

      # Make sure the session_id in the CSRF token points to the cookie one
      true <- token_session_id == cookie_session_id || :token_mismatch
    do
      # Happy path! Everything ok. Proceed.
      conn
    else
      # Requested page does not need a CSRF token; proceed.
      :exempt ->
        conn

      # CSRF token has expired
      {:error, :too_old} ->
        halt_error(conn, :token_expired)

      # Could not decrypt the CSRF token, possibly has been tampered
      {:error, reason} ->
        halt_error(conn, :token_invalid)

      # There is no token, no session or the token maps to another session
      error when is_atom(error) ->
        halt_error(conn, error)
    end
  end
end
