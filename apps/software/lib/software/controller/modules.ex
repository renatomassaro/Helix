defmodule HELM.Software.Controller.Module do
  import Ecto.Query

  alias HELM.Software.Model.Repo
  alias HELM.Software.Model.Module, as: MdlModule

  def create(role, file_id, version) do
    %{module_role: role,
      file_id: file_id,
      module_version: version}
    |> MdlModule.create_changeset()
    |> Repo.insert()
  end

  def find(role, file_id) do
    case Repo.get_by(MdlModule, module_role: role, file_id: file_id) do
      nil -> {:error, :notfound}
      res -> {:ok, res}
    end
  end

  def delete(role, file_id) do
    case find(role, file_id) do
      {:ok, file} -> Repo.delete(file)
      error -> error
    end
  end
end
