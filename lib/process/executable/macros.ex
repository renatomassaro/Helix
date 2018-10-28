# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule Helix.Process.Executable.Macros do

  alias HELL.Macros.Utils, as: MacroUtils
  alias Helix.Log.Model.Log
  alias Helix.Network.Model.Connection
  alias Helix.Server.Model.Server
  alias Helix.Software.Model.File
  alias Helix.Universe.Bank.Model.BankAccount
  alias Helix.Process.Model.Process

  defmacro __using__(_) do
    quote do

      Module.register_attribute(__MODULE__, :callbacks, accumulate: true)

      @on_definition unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

    end
  end

  defmacro __before_compile__(env) do
    process = MacroUtils.get_parent_module(env.module)

    quote do

      @type params :: unquote(process).creation_params

      unless :custom in @callbacks,
        do: @type custom :: %{}

      for callback <- Enum.uniq(@callbacks) do
        case callback do
          :custom ->
            @spec custom(Server.t, Server.t, params, meta) ::
              custom

          :resources ->
            @spec resources(Server.t, Server.t, params, meta, custom) ::
              unquote(process).resources_params

          :source_connection ->
            @spec source_connection(Server.t, Server.t, params, meta, custom) ::
              Connection.idt
              | {:create, Connection.type}
              | :same_origin
              | nil | :ok | :noop

          :target_connection ->
            @spec target_connection(Server.t, Server.t, params, meta, custom) ::
              Connection.idt
              | {:create, Connection.type}
              | :same_origin
              | nil | :ok | :noop

          :source_file ->
            @spec source_file(Server.t, Server.t, params, meta, custom) ::
              File.idt | nil

          :target_file ->
            @spec target_file(Server.t, Server.t, params, meta, custom) ::
              File.idt | nil

          :target_process ->
            @spec target_process(Server.t, Server.t, params, meta, custom) ::
              Process.idt | nil

          :target_log ->
            @spec target_log(Server.t, Server.t, params, meta, custom) ::
              Log.idt | nil

          :target_bank_account ->
            @spec target_bank_account(Server.t, Server.t, params, meta, custom) ::
              BankAccount.t
        end
      end

    end
  end

  def __on_definition__(env, _kind, name, _args, _guards, _body),
    do: Module.put_attribute(env.module, :callbacks, name)
end
