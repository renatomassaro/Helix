# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule Helix.Process.Resourceable.Macros do

  alias HELL.Macros.Utils, as: MacroUtils
  alias Helix.Network.Model.Network
  alias Helix.Process.Model.Process
  alias Helix.Process.Resourceable

  defmacro __using__(_) do
    quote do

      import Helix.Factor.Client

      Module.register_attribute(__MODULE__, :callbacks, accumulate: true)

      @on_definition unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @after_compile unquote(__MODULE__)

    end
  end

  defmacro __before_compile__(env) do
    process = MacroUtils.get_parent_module(env.module)

    quote do
      @type params :: unquote(process).resources_params

      for callback <- Enum.uniq(@callbacks) do
        case callback do
          {:cpu, 2} ->
            @spec cpu(factors, params) :: Resourceable.resource_usage

          {:ram, 2} ->
            @spec ram(factors, params) :: Resourceable.resource_usage

          {:dlk, 2} ->
            @spec dlk(factors, params) :: Resourceable.resource_usage

          {:ulk, 2} ->
            @spec ulk(factors, params) :: Resourceable.resource_usage

          {:network_id, 0} ->
            @spec network_id :: Network.id | nil

          {:network_id, 1} ->
            @spec network_id(params) :: Network.id | nil

          {:network_id, 2} ->
            @spec network_id(factors, params) :: Network.id | nil

          {:static, 0} ->
            @spec static :: Process.static

          {:static, 1} ->
            @spec static(params) :: Process.static

          {:static, 2} ->
            @spec static(factors, params) :: Process.static

          {:dynamic, 0} ->
            @spec dynamic :: Process.dynamic

          {:dynamic, 1} ->
            @spec dynamic(params) :: Process.dynamic

          {:dynamic, 2} ->
            @spec dynamic(factors, params) :: Process.dynamic

          {:r_dynamic, 0} ->
            @spec r_dynamic :: Process.dynamic

          {:r_dynamic, 1} ->
            @spec r_dynamic(params) :: Process.dynamic

          {:r_dynamic, 2} ->
            @spec r_dynamic(factors, params) :: Process.dynamic

          {:get_factors, 1} ->
            :noop
        end
      end
    end
  end

  defmacro __after_compile__(_, _) do
    sanity_checks()
  end

  def sanity_checks do
    quote do

      callbacks =
        :functions
        |> __MODULE__.__info__()
        |> Enum.into(%{})

      with \
        false <- Map.has_key?(callbacks, :cpu),
        false <- Map.has_key?(callbacks, :ram),
        false <- Map.has_key?(callbacks, :dlk),
        false <- Map.has_key?(callbacks, :ulk)
      do
        raise "Missing resource handlers for #{__MODULE__}"
      end

      with \
        true <- Map.has_key?(callbacks, :dlk) or Map.has_key?(callbacks, :ulk),
        false <- Map.has_key?(callbacks, :network_id)
      do
        raise "You forgot to specify the `network_id` resource at #{__MODULE__}"
      end

      if Map.has_key?(callbacks, :network),
        do: raise "It's `network_id`, not `network`"

    end
  end

  def __on_definition__(env, _kind, name, args, _guards, _body),
    do: Module.put_attribute(env.module, :callbacks, {name, length(args)})
end
