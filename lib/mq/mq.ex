defmodule Helix.MQ do

  alias Helix.MQ

  def publish(node_id, queue, message) do
    data = %{queue: queue, data: message} |> Poison.encode!()

    MQ.Client.publish(node_id, data)
  end

  defdelegate subscribe(queue, callback),
    to: MQ.Router
  defdelegate register_node(node_id, ip, port),
    to: MQ.Client
  defdelegate unregister_node(node_id),
    to: MQ.Client
end
