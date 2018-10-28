defmodule Helix.Process.Public.Index do

  alias Helix.Entity.Model.Entity
  alias Helix.Server.Model.Server
  alias Helix.Process.Model.Process
  alias Helix.Process.Public.View.Process, as: ProcessView
  alias Helix.Process.Query.Process, as: ProcessQuery

  @type index :: [Process.t]

  @type rendered_index :: [ProcessView.process]

  @spec index(Server.id, Entity.id) ::
    index
  @doc """
  Index for processes residing within the given server.
  """
  def index(server_id, entity_id) do
    server_id
    |> ProcessQuery.get_processes_from_entity_on_server(entity_id)
  end

  @spec render_index(index, Server.id, Entity.id) ::
    rendered_index
  def render_index(index, server_id, entity_id) do
    index
    |> Enum.map(&ProcessView.render(&1, server_id, entity_id))
    |> Enum.reject(&(&1 == nil))
  end
end
