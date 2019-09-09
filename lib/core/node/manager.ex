defmodule Helix.Core.Node.Manager do

  alias Helix.MQ
  alias Helix.Core.Node

  @node_data Application.get_env(:helix, :node) |> Enum.into(%{})

  # TODO: This is generated at compile time, so it's WRONG
  @random_node_identifier SecureRandom.random_bytes(2) |> Base.encode16()

  def get_node_name do
    %{provider: provider, region: region} = get_node_data()

    provider <> "_" <> region <> "_" <> @random_node_identifier
    |> String.downcase()
  end

  def get_node_private_ip,
    do: get_node_data().private_ip

  def on_startup do
    node_name = get_node_name()
    private_ip = get_node_private_ip()

    # Checks / verifications to make sure this node is ready to receive traffic

    # Register this node at the database

    # Notify the leader

    # Add own node connection to Helix.MQ client list
    Helix.MQ.register_node(node_name, private_ip, 5000)

    # Setup Helix.MQ connection with other existing nodes
  end

  defp get_node_data,
    do: @node_data
end
