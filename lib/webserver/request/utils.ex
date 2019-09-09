defmodule Helix.Webserver.Request.Utils do
  @moduledoc """
  Utils for `Helix.Webserver.Request`
  """

  alias Plug.Conn
  alias HELL.IPv4
  alias Helix.Core.Validator
  alias Helix.Network.Model.Bounce
  alias Helix.Network.Model.Network
  alias Helix.Webserver.Session, as: SessionWeb

  @spec validate_nip(unsafe :: String.t | Network.id, unsafe_ip :: String.t) ::
    {:ok, Network.id, Network.ip}
    | :bad_request
  @doc """
  Ensures the given nip, which is unsafe (user input), is valid and within the
  expected format.

  NOTE: This function does not check whether the nip exists.
  """
  def validate_nip(unsafe_network_id, unsafe_ip) do
    with \
      {:ok, network_id} <- Network.ID.cast(unsafe_network_id),
      true <- IPv4.valid?(unsafe_ip)
    do
      {:ok, network_id, unsafe_ip}
    else
      _ ->
        :bad_request
    end
  end

  @spec validate_input(unsafe_input :: String.t, Validator.input_type, term) ::
    {:ok, Validator.validated_inputs}
    | :bad_request
  @doc """
  Delegates the input validation to `Validator`.
  """
  def validate_input(input, type, opts \\ []) do
    case Validator.validate_input(input, type, opts) do
      {:ok, valid_input} ->
        {:ok, valid_input}

      :error ->
        :bad_request
    end
  end

  @spec validate_bounce(unsafe_bounce :: String.t | nil) ::
    {:ok, nil}
    | {:ok, Bounce.id}
    | :bad_request
  @doc """
  Ensures the given bounce is valid. It may either be nil (i.e. no bounce) or
  a valid Bounce.ID.

  NOTE: This function does not check whether the bounce exists.
  """
  def validate_bounce(nil),
    do: {:ok, nil}
  def validate_bounce(bounce_id) do
    case Bounce.ID.cast(bounce_id) do
      {:ok, bounce_id} ->
        {:ok, bounce_id}

      :error ->
        :bad_request
    end
  end

  @spec cast_existing_atom(String.t) ::
    {:ok, atom}
    | {:error, :atom_not_found}
  @doc """
  Ensures the given string already exists as an atom, and also converts it to an
  atom.
  """
  def cast_existing_atom(unsafe) do
    try do
      atom = String.to_existing_atom(unsafe)
      {:ok, atom}
    rescue
      _ ->
        {:error, :atom_not_found}
    end
  end

  @spec cast_optional(map, binary | atom, function, default :: term) ::
    {:ok, casted :: term}
    | default :: term
  @doc """
  Helper that casts optional parameters, falling back to `default` when they
  have not been specified.
  """
  def cast_optional(request, key, cast_function, default \\ nil)
  def cast_optional(request, key, cast_function, default) when is_atom(key),
    do: cast_optional(request, to_string(key), cast_function, default)
  def cast_optional(request, key, cast_function, default) do
    if Map.has_key?(request.unsafe, key) do
      cast_function.(request.unsafe[key])
    else
      default
    end
  end

  @spec input_optional(map, binary | atom, default :: term) ::
    term
  @doc """
  Returns the given value or an optional one (`default`).
  """
  def input_optional(request, key, default \\ nil) do
    if Map.has_key?(request.unsafe, key) do
      request.unsafe[key]
    else
      default
    end
  end

  @spec cast_list_of_ids([unsafe_ids :: term] | nil, function) ::
    {:ok, [casted_ids :: term]}
    | {:bad_id, unsafe_id :: term}
    | :bad_request
  @doc """
  Helper to automatically cast a list of IDs - it applies `cast_fun` to all
  members of `elements`, accumulating the result.

  May return `:bad_request` when input is not a list, or `{:bad_id, unsafe_id}`
  when one of the IDs failed to cast.
  """
  def cast_list_of_ids(elements, _fun) when not is_list(elements),
    do: :bad_request
  def cast_list_of_ids(elements, cast_fun) when is_function(cast_fun) do
    Enum.reduce_while(elements, {:ok, []}, fn unsafe_id, {_, acc} ->
      case cast_fun.(unsafe_id) do
        {:ok, element_id} ->
          {:cont, {:ok, acc ++ [element_id]}}

        :error ->
          {:halt, {:bad_id, unsafe_id}}
      end
    end)
  end

  @spec ensure_type(:binary, String.t) :: {:ok, String.t}
  @spec ensure_type(:binary, list | integer | map | boolean) :: :error
  @spec ensure_type(:bool, boolean) :: {:ok, boolean}
  @spec ensure_type(:bool, String.t | list | integer | map) :: :error
  @spec ensure_type(:integer, term) ::
    {:ok, boolean}
    | :error

  @doc """
  Ensures that the given `input` belongs to the underlying type.
  """
  def ensure_type(:binary, input) when is_binary(input),
    do: {:ok, input}
  def ensure_type(:binary, _),
    do: :error
  def ensure_type(:bool, input) when is_boolean(input),
    do: {:ok, input}
  def ensure_type(:bool, _),
    do: :error
  def ensure_type(:integer, input) when is_integer(input),
    do: {:ok, input}
  def ensure_type(:integer, input) when not is_binary(input),
    do: :error
  def ensure_type(:integer, input) do
    case Integer.parse(input) do
      {number, ""} ->
        {:ok, number}

      {_, _} ->
        # It's a float
        :error

      :error ->
        :error
    end
  end

  def parse_nip(nip) when is_binary(nip) do
    case SessionWeb.parse_server_cid(nip) do
      {:nip, parsed_nip} ->
        {:ok, parsed_nip}

      _ ->
        :error
    end
  end

  @doc """
  Retrieve the request's UserAgent
  """
  def fetch_user_agent(%{conn: conn = %Conn{}}) do
    case Conn.get_req_header(conn, "user-agent") do
      [user_agent] ->
        user_agent

      [] ->
        ""
    end
  end

  @doc """
  Retrieve the request's client IP (as defined by EntrypointPlug)
  """
  def fetch_client_ip(%{conn: conn = %Conn{}}),
    do: conn.assigns.client_ip
end
