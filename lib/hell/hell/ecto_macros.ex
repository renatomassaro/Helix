defmodule HELL.Ecto.Macros do

  @id_map %{
    account: "Account.Model.Account",
    bounce: "Network.Model.Bounce",
    bounce_entry: "Network.Model.Bounce.Entry",
    bounce_sorted: "Network.Model.Bounce.Sorted",
    component: "Server.Model.Component",
    connection: "Network.Model.Connection",
    file: "Software.Model.File",
    entity: "Entity.Model.Entity",
    log: "Log.Model.Log",
    network: "Network.Model.Network",
    npc: "Universe.NPC.Model.NPC",
    process: "Process.Model.Process",
    server: "Server.Model.Server",
    storage: "Software.Model.Storage",
    tunnel: "Network.Model.Tunnel"
  }

  @doc """
  Syntactic-sugar for our way-too-common Query module
  """
  defmacro query(do: block) do
    quote do

      defmodule Query do
        @moduledoc false

        import Ecto.Query

        alias Ecto.Queryable
        alias unquote(__CALLER__.module)

        unquote(block)
      end

    end
  end

  @doc """
  Syntactic-sugar for the less-common Order module
  """
  defmacro order(do: block) do
    quote do

      defmodule Order do
        @moduledoc false

        import Ecto.Query

        alias Ecto.Queryable
        alias unquote(__CALLER__.module)

        unquote(block)
      end

    end
  end

  @doc """
  Syntactic-sugar for the even less-common Select module
  """
  defmacro select(do: block) do
    quote do

      defmodule Select do
        @moduledoc false

        import Ecto.Query

        alias Ecto.Queryable
        alias unquote(__CALLER__.module)

        unquote(block)
      end

    end
  end

  @doc """
  Generates and then inserts the Helix.ID into the changeset.

  A custom ID module may be specified at `opts`, otherwise __CALLER__.ID shall
  be used.
  """
  defmacro put_pk(changeset, heritage, domain, opts \\ unquote([])) do
    module = get_pk_module(opts, __CALLER__.module)

    gen_pk(changeset, heritage, domain, module)
  end

  defmacro id do
    quote do
      Module.concat(__MODULE__, :ID)
    end
  end

  @doc """
  This is a hack intended to indirectly refer another schema's ID (usually as
  FK) without creating a compilation dependency.

  See https://github.com/elixir-ecto/ecto/issues/1610
  """
  defmacro id(name) do
    module = id_table(name)

    quote do
      unquote(module)
    end
  end

  defp id_table(table) do
    Module.concat([
      :Helix,
      @id_map[table] |> String.to_atom(),
      :ID
    ])
  end

  defp gen_pk(changeset, heritage, domain, module) do
    quote do

      if unquote(changeset).valid? do
        field = unquote(module).get_field()
        id = unquote(module).generate(unquote(heritage), unquote(domain))

        put_change(unquote(changeset), field, id)
      else
        unquote(changeset)
      end

    end
  end

  defp get_pk_module([id: module], _),
    do: module
  defp get_pk_module([], parent_module),
    do: Module.concat(parent_module, :ID)
end
