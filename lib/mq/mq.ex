defmodule Helix.MQ do

  alias Helix.Core.Node.Manager, as: NodeManager
  alias Helix.MQ

  @node_id NodeManager.get_node_name()

  def publish(@node_id, queue, message) do
    # We still have to perform this seemingly idempotent operation to make sure
    # the message received by `dispatch` is always the same, regardless of the
    # origin.
    stringified_message =
      message
      |> Poison.encode!()
      |> Poison.decode!(keys: :atoms)

    MQ.Router.dispatch(queue, stringified_message)
  end

  def publish(node_id, queue, message) do
    payload =
      %{queue: queue, data: message}
      |> Poison.encode!()
      |> Kernel.<>("EOF")

    MQ.Client.publish(node_id, payload)
  end

  def multicast(queue, msg) do
    IO.puts "Multicast todo"

    publish(@node_id, queue, msg)
  end

  defdelegate subscribe(queue, callback),
    to: MQ.Router
  defdelegate register_node(node_id, ip, port),
    to: MQ.Client
  defdelegate unregister_node(node_id),
    to: MQ.Client
end
