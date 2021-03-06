defmodule Helix.Software.Internal.File do

  alias Helix.Software.Model.File
  alias Helix.Software.Model.Storage
  alias Helix.Software.Repo
  alias __MODULE__, as: FileInternal

  @spec fetch(File.id) ::
    File.t
    | nil
  def fetch(file_id) do
    file =
      file_id
      |> File.Query.by_file()
      |> Repo.one()

    if file do
      format(file)
    end
  end

  @spec fetch_best(Storage.t, File.Module.name) ::
    best :: File.t
    | nil
  def fetch_best(storage, module) do
    best =
      storage
      |> File.Query.by_version(module)
      |> File.Query.only(1)
      |> Repo.all()

    case best do
      [file] ->
        file
        |> Repo.preload(:modules)
        |> format()

      [] ->
        nil
    end
  end

  @spec get_files_on_storage(Storage.idt) ::
    [File.t]
  @doc """
  Gets all files on `storage`.
  """
  def get_files_on_storage(storage) do
    storage
    |> File.Query.by_storage()
    |> Repo.all()
    |> Enum.map(&format/1)
  end

  @spec format(File.t) ::
    File.t
  @doc """
  Formats the file, making sure its metadata is retrieved and its modules are
  converted to a more friendly format (defined by File.Module).
  """
  def format(file = %File{}) do
    file
    |> FileInternal.Meta.gather_metadata()
    |> File.format()
  end

  @spec create(File.creation_params, File.modules) ::
    {:ok, File.t}
    | {:error, Ecto.Changeset.t}
  @doc """
  Creates a new file, according to the given params and modules.

  Modules, if any, are inserted alongside the file, in a transaction.
  """
  def create(file_params, modules) do
    # TODO: Check storage requirements #279
    result =
      file_params
      |> File.create_changeset(modules)
      |> Repo.insert()

    with {:ok, file} <- result do
      {:ok, format(file)}
    end
  end

  @spec update(File.t, File.update_params) ::
    {:ok, File.t}
    | {:error, File.changeset}
  defp update(file, params) do
    file
    |> File.update_changeset(params)
    |> Repo.update()
  end

  @type copy_params ::
    %{
      path: File.path,
      name: File.name
    }

  @spec copy(File.t, Storage.t, copy_params) ::
    {:ok, File.t}
    | {:error, File.changeset}
  def copy(file, storage, params = %{}) do
    params = %{
      name: params.name,
      path: params.path,
      file_size: file.file_size,
      storage_id: storage.storage_id,
      software_type: file.software_type
    }

    modules =
      Enum.reduce(file.modules, [], fn ({module, data}, acc) ->
        acc ++ [{module, data}]
      end)

    create(params, modules)
  end

  @spec move(File.t, File.path) ::
    {:ok, File.t}
    | {:error, File.changeset}
  def move(file, path) do
    params = %{path: path}

    update(file, params)
  end

  @spec rename(File.t, File.name) ::
    {:ok, File.t}
    | {:error, File.changeset}
  def rename(file, file_name) do
    params = %{name: file_name}

    update(file, params)
  end

  @spec encrypt(File.t, File.Module.version) ::
    {:ok, File.changeset}
    | {:error, File.changeset}
  def encrypt(file = %File{}, version) when version >= 1 do
    file
    |> File.update_changeset(%{crypto_version: version})
    |> Repo.update()
  end

  @spec decrypt(File.t) ::
    {:ok, File.changeset}
    | {:error, File.changeset}
  def decrypt(file = %File{}) do
    file
    |> File.update_changeset(%{crypto_version: nil})
    |> Repo.update()
  end

  @spec delete(File.t) ::
    :ok
  def delete(file) do
    Repo.delete(file)

    :ok
  end
end
