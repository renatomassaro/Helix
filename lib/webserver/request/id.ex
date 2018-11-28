defmodule Helix.Webserver.Request.ID do

  import HELL.Macros.Docp

  alias Helix.ID

  @prefix_auth "req-"
  @prefix_unauth "urq-"

  def generate_id(conn = %Plug.Conn{}),
    do: generate_id(conn.assigns[:session], conn)

  # ureq-i(6)r(22)
  def generate_id(nil, conn) do
    hash_ip = get_ip_hash(conn.remote_ip)
    hash_random = get_random_chars(23)

    @prefix_unauth <> hash_ip <> hash_random
    |> String.downcase()
  end

  # req-e(12)s(2)t(8)r(6)
  def generate_id(%{account_id: account_id, session_id: session_id}, _) do
    hash_account = get_account_hash(account_id, 12)
    hash_session = get_session_hash(session_id, 2)
    hash_time = ID.hash_time() |> ID.Utils.bin_to_hex(8)
    hash_random = get_random_chars(6)

    @prefix_auth <> hash_account <> hash_session <> hash_time <> hash_random
    |> String.downcase()
  end

  def generate_id(%{context: context}, conn),
    do: generate_id(context, conn)
  def generate_id(empty_map, conn) when map_size(empty_map) == 0,
    do: conn.assigns.request_id

  defp get_account_hash(account_id, size) do
    account_id
    |> to_string()
    |> String.replace(":", "")
    |> String.slice(0..size - 1)
  end

  defp get_session_hash(session_id, size),
    do: String.slice(session_id, 0..size - 1)

  defp get_ip_hash({oct1, oct2, oct3, _}) do
     p1 = oct1 |> Integer.to_string(2) |> ID.Utils.bin_to_hex(2)
     p2 = oct2 |> Integer.to_string(2) |> ID.Utils.bin_to_hex(2)
     p3 = oct3 |> Integer.to_string(2) |> ID.Utils.bin_to_hex(2)

     p1 <> p2 <> p3
  end

  docp """
  Not using `ID.Utils.random_bits/1` because that is entropy-safe (and thus a
  lot more demanding). We do not need this safety here.
  """
  defp get_random_chars(size) do
    Ecto.UUID.generate()
    |> String.replace("-", "")
    |> String.slice(0..size - 1)
  end
end
