defmodule Helix.Process do

  defmacro __using__(_env) do
    quote do

      import Hembed
      import unquote(__MODULE__)

    end
  end

  defmacro process_struct(args) do
    quote do

      defstruct unquote(args)

    end
  end

  defmacro process(name, do: block) do
    quote do

      defmodule unquote(name) do

        @type resource_usage :: number  # TODO: Check comp graph
        @type executable_error :: Helix.Process.Executable.error

        @process_type nil

        @doc false
        def execute(gateway, target, params, meta, relay) do
          params = [__MODULE__, gateway, target, params, meta, relay]

          apply(executable_module(), :execute, params)
        end

        @doc false
        def resources(params),
          do: apply(resourceable_module(), :get_resources, [__MODULE__, params])

        unquote(block)

        defp executable_module,
          do: Module.concat(Helix.Process, :Executable)

        defp resourceable_module,
          do: Module.concat(Helix.Process, :Resourceable)

        if @process_type do

          @doc """
          Returns the process type.
          """
          def get_process_type(_, _),
            do: @process_type

        end

      end
    end
  end

  defmacro processable(do: block) do
    quote do

      hembed Processable do
        use Helix.Process.Processable.Macros
        unquote(block)
      end

    end
  end

  defmacro resourceable(do: block) do
    quote do

      hembed Resourceable do
        use Helix.Process.Resourceable.Macros
        unquote(block)
      end

    end
  end

  defmacro executable(do: block) do
    quote do

      hembed Executable do
        use Helix.Process.Executable.Macros
        unquote(block)
      end

    end
  end

  defmacro viewable(do: block) do
    quote do

      hembed Viewable do
        unquote(block)
      end

    end
  end
end
