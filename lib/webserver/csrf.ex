defmodule Helix.Webserver.CSRF do

  @csrf_token_key "_csrf-token"
  @private_key :hairnet.generate_encoded_key()
  @token_ttl 30 * 60  # 30 minutes

  def get_csrf_token(conn) do
    conn.params[@csrf_token_key]
  end

  def generate_token(session_id) when is_binary(session_id) do
    session_id
    |> :hairnet.generate_token(@private_key)
  end

  def validate_token(token) do
    token
    |> :hairnet.verify_and_decrypt_token(@private_key, @token_ttl)
  end

  def requires_csrf?("POST", [_, "account", "register"]),
    do: false
  def requires_csrf?("POST", [_, "account", "check-username"]),
    do: false
  def requires_csrf?("POST", [_, "account", "check-email"]),
    do: false
  def requires_csrf?("POST", [_, "login"]),
    do: false
  def requires_csrf?("POST", [_, "account", "verify"]),
    do: false
  def requires_csrf?("GET", [_, "check-session"]),
    do: false
  def requires_csrf?("GET", [_, "ping"]),
    do: false

  # Mostly untested. Once tested, remove the above `get` clauses.
  def requires_csrf?("GET", _),
    do: false
  def requires_csrf?(_, _),
    do: true
end
