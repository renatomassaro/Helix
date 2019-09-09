defmodule Helix.Core.Validator do

  alias HELL.IPv4
  alias Helix.Notification.Model.Notification

  @type input_type ::
    :password
    | :hostname
    | :bounce_name
    | :reply_id
    | :notification_id

  @type validated_inputs ::
    String.t
    | Notification.Validator.validated_inputs

  @regex_alphabet ~r/[a-zA-Z0-9]/
  @regex_hostname ~r/^[a-zA-Z0-9-_.@#]{1,20}$/
  @regex_username ~r/^[a-zA-Z0-9-_]{3,15}$/

  @spec validate_input(input :: String.t, input_type, opts :: term) ::
    {:ok, validated_inputs}
    | :error
  @doc """
  This is a generic function meant to validate external input that does not
  conform to a specific shape or format (like internal IDs or IP addresses).

  The `element` argument identifies what the input is supposed to represent, and
  we leverage this information to customize the validation for different kinds
  of input.
  """
  def validate_input(input, type, opts \\ [])

  def validate_input(input, :username, _),
    do: validate_username(input)

  def validate_input(input, :account_password, _),
    do: validate_account_password(input)

  def validate_input(input, :server_password, _),
    do: validate_server_password(input)

  def validate_input(input, :email, _),
    do: validate_email(input)

  def validate_input(input, :verification_key, _),
    do: validate_verification_key(input)

  def validate_input(input, :hostname, _),
    do: validate_hostname(input)

  def validate_input(input, :client, _),
    do: validate_client(input)

  def validate_input(input, :bounce_name, _),
    do: validate_bounce_name(input)

  def validate_input(input, :reply_id, _),
    do: validate_reply_id(input)

  def validate_input(input, :notification_id, opts),
    do: Notification.Validator.validate_id(input, opts)

  def validate_input(input, :ipv4, _),
    do: validate_ipv4(input)

  # Implementations

  defp validate_hostname(v),
    do: check_regex(v, @regex_hostname)

  defp validate_username(v),
    do: check_regex(v, @regex_username)

  defp validate_server_password(v),
    do: check_regex(v, @regex_hostname)

  defp validate_account_password(v) do
    if String.length(v) < 6 do
      :error
    else
      {:ok, v}
    end
  end

  defp validate_email(v) do
    with \
      true <- String.length(v) >= 3,
      true <- String.contains?(v, "@")
    do
      {:ok, v}
    else
      _ ->
        :error
    end
  end

  defp validate_verification_key(v) when not is_binary(v),
    do: :error
  defp validate_verification_key(v) do
    with \
      true <- String.length(v) == 6,
      true <- Regex.match?(@regex_alphabet, v)
    do
      {:ok, v}
    else
      _ ->
        :error
    end
  end

  defp validate_bounce_name(v),
    do: validate_hostname(v)  # TODO

  defp validate_reply_id(v),
    do: validate_hostname(v)  # TODO

  defp validate_client("web1"),
    do: {:ok, :web1}
  defp validate_client("web2"),
    do: {:ok, :web2}
  defp validate_client(_),
    do: :error

  defp validate_ipv4(v) do
    if IPv4.valid?(v) do
      {:ok, v}
    else
      :error
    end
  end

  # Utils

  defp check_regex(v, _) when not is_binary(v),
    do: :error
  defp check_regex(v, regex) do
    if Regex.match?(regex, v) do
      {:ok, v}
    else
      :error
    end
  end
end
