defmodule HELL.ClientUtils do

  alias HELL.HETypes
  alias Helix.Account.Model.Account
  alias Helix.Network.Model.Network
  alias Helix.Server.Model.Server

  @internet_id Network.internet_id()

  @spec to_timestamp(DateTime.t) ::
    HETypes.client_timestamp
  @doc """
  Converts the given `DateTime.t` to the format expected by the client
  """
  def to_timestamp(datetime = %DateTime{}) do
    datetime
    |> DateTime.to_unix(:millisecond)
    |> Kernel./(1)  # Make it a float...
  end

  @spec to_nip(%{network_id: Network.id, ip: Network.ip}) :: HETypes.client_nip
  @spec to_nip(%{network_id: String.t, ip: String.t}) :: HETypes.client_nip
  @spec to_nip(Network.id, Network.ip) :: HETypes.client_nip
  @spec to_nip({Network.id, Network.ip}) :: HETypes.client_nip

  @doc """
  Generic method to convert a nip to the correct format expected by the client
  """
  def to_nip(nip = %{network_id: network_id, ip: _}) when is_binary(network_id),
    do: nip
  def to_nip(%{network_id: network_id = %Network.ID{}, ip: ip}),
    do: to_nip(network_id, ip)
  def to_nip({network_id = %Network.ID{}, ip}),
    do: %{network_id: to_string(network_id), ip: ip}
  def to_nip(network_id = %Network.ID{}, ip),
    do: %{network_id: to_string(network_id), ip: ip}

  def to_cid(account_id = %Account.ID{}),
    do: cid_id(account_id)
  def to_cid(server_id = %Server.ID{}),
    do: cid_id(server_id)
  def to_cid({@internet_id, ip}) when is_binary(ip),
    do: ip <> "$" <> "*"
  def to_cid({network_id = %Network.ID{}, ip}) when is_binary(ip),
    do: ip <> "$" <> cid_network(network_id)

  defp cid_network(@internet_id),
    do: "*"
  defp cid_network(network_id = %Network.ID{}),
    do: cid_id(network_id)

  defp cid_id(helix_id = %_{}),
    do: cid_id(to_string(helix_id))
  defp cid_id(helix_id),
    do: String.replace(helix_id, ":", ",")
end
