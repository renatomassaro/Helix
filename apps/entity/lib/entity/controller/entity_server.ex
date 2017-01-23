defmodule Helix.Entity.Controller.EntityServer do

  alias Helix.Server.Model.Server
  alias Helix.Entity.Model.Entity
  alias Helix.Entity.Model.EntityServer
  alias Helix.Entity.Repo

  import Ecto.Query, only: [where: 3]

  @spec create(Entity.id, Server.id) :: {:ok, EntityServer.t} | {:error, Ecto.Changeset.t}
  def create(entity_id, server_id) do
    %{entity_id: entity_id, server_id: server_id}
    |> EntityServer.create_changeset()
    |> Repo.insert()
  end

  # FIXME: choose a better function name
  @spec get_entity(Server.id) :: EntityServer.t
  def get_entity(server_id) do
    EntityServer
    |> where([s], s.server_id == ^server_id)
    |> Repo.one()
  end

  @spec find(Entity.id) :: [EntityServer.t]
  def find(entity_id) do
    EntityServer
    |> where([s], s.entity_id == ^entity_id)
    |> Repo.all()
  end

  @spec delete(Entity.id, Server.id) :: no_return
  def delete(entity_id, server_id) do
    EntityServer
    |> where([s], s.entity_id == ^entity_id)
    |> where([s], s.server_id == ^server_id)
    |> Repo.delete_all()

    :ok
  end
end