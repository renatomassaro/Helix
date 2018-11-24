defmodule Helix.Core.Node.Monitor do

  alias Helix.Core.Node.Manager, as: NodeManager

  use GenServer

  @registry_name :node_monitor

  def start_link,
    do: GenServer.start_link(__MODULE__, [], name: @registry_name)

  def init(_) do
    spawn fn ->
      Application.ensure_started(:helix)

      GenServer.cast(@registry_name, :on_startup)
    end

    {:ok, %{}}
  end

  def handle_cast(:on_startup, state) do
    NodeManager.on_startup()

    {:noreply, state}
  end
end
