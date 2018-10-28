defmodule Helix.Process.Executable do

  import HELF.Flow
  import HELL.Macros.Docp

  alias Helix.Event
  alias Helix.Entity.Model.Entity
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Network.Model.Bounce
  alias Helix.Network.Model.Network
  alias Helix.Server.Model.Server
  alias Helix.Process.Action.Process, as: ProcessAction
  alias Helix.Process.Model.Process
  alias __MODULE__, as: Executable

  @type executable :: atom
  @type params :: map
  @type meta :: map
  @type custom :: map

  @type error ::
    {:error, :resources}
    | {:error, :internal}

  @spec execute(module :: atom, Server.t, Server.t, params, meta, Event.relay) ::
    {:ok, Process.t}
    | error
  def execute(process, gateway, target, params, meta, relay) do
    executable = get_executable_hembed(process)
    callbacks = get_implemented_callbacks(executable)
    args = [gateway, target, params, meta]

    flowing do
      with \
        {:ok, params} <- get_params(executable, args, callbacks, relay),

        # *Finally* create the process
        {:ok, process, events} <- ProcessAction.create(params),

        # Notify the process has been created (ProcessCreatedEvent)
        on_success(fn -> Event.emit(events, from: relay) end)

        # Note that at this stage, we are not absolutely sure the process will
        # be confirmed/saved, as the `ProcessAction.create/1` step is
        # optimistic. If the server does not have enough resources to run that
        # process, or some ~wild event occurs~, the process may not be correctly
        # allocated and, as a result, deleted.
        # Check `ProcessCreatedEvent` documentation for more details.
      do
        {:ok, process}
      else
        {:error, :resources} ->
          {:error, :resources}

        {:error, %Ecto.Changeset{}} ->
          {:error, :internal}

        _ ->
          {:error, :internal}
      end
    end
  end

  defp get_params(executable, args = [_, _, params, meta], callbacks, relay) do
    # Custom pre-hook
    custom = callback(executable, :custom, args, callbacks)
    args = args ++ [custom]

    # Executable callbacks
    resources_params = callback(executable, :resources, args, callbacks)
    source_file = callback(executable, :source_file, args, callbacks)
    target_file = callback(executable, :target_file, args, callbacks)
    target_process = callback(executable, :target_process, args, callbacks)
    target_log = callback(executable, :target_log, args, callbacks)
    src_bank_acc = callback(executable, :source_bank_account, args, callbacks)
    tgt_bank_acc = callback(executable, :target_bank_account, args, callbacks)

    source_connection_info =
      callback(executable, :source_connection, args, callbacks)
    target_connection_info =
      callback(executable, :target_connection, args, callbacks)

    # Derived data
    process_data = get_process_data(executable, params, meta)
    process_type = get_process_type(executable, params, meta)
    ownership = get_ownership(args)
    network_id = get_network_id(meta[:network_id])
    bounce_id = get_bounce_id(meta[:bounce])
    resources = get_resources(executable, resources_params)

    partial =
      process_data
      |> Map.merge(process_type)
      |> Map.merge(ownership)
      |> Map.merge(network_id)
      |> Map.merge(bounce_id)
      |> Map.merge(resources)
      |> Map.merge(source_file)
      |> Map.merge(target_file)
      |> Map.merge(target_process)
      |> Map.merge(target_log)
      |> Map.merge(src_bank_acc)
      |> Map.merge(tgt_bank_acc)

    flowing do
      with \
        {:ok, src_connection} <-
          setup_connection(args, source_connection_info, nil, relay),
        {:ok, tgt_connection} <-
          setup_connection(args, target_connection_info, src_connection, relay),
        params = merge_params(partial, src_connection, tgt_connection)
      do
        {:ok, params}
      end
    end
  end

  defp callback(executable, method, args, callbacks) do
    result =
      case Keyword.fetch(callbacks, method) do
        {:ok, _} ->
          apply(executable, method, args)

        :error ->
          apply(__MODULE__.Defaults, method, args)
      end

    Executable.Formatter.format(method, result)
  end

  docp """
  Returns the `process_data` parameter, a subset of the full process params.
  """
  def get_process_data(executable, params, meta),
    do: %{data: call_process(executable, :new, [params, meta])}

  @spec get_process_type(executable, params, meta) ::
    %{type: Process.type}
  docp """
  Returns the `process_type` parameter, a subset of the full process params.
  """
  def get_process_type(_, _, %{type: process_type}),
    do: %{type: process_type}
  def get_process_type(executable, params, meta),
    do: %{type: call_process(executable, :get_process_type, [params, meta])}

  @spec get_ownership(list) ::
    %{
      gateway_id: Server.id,
      target_id: Server.id,
      source_entity_id: Entity.id
    }
  docp """
  Infers ownership information about the process, a subset of the full process
  params.
  """
  defp get_ownership([gateway, target, _params, _meta, _custom]) do
    entity = EntityQuery.fetch_by_server(gateway.server_id)

    %{
      gateway_id: gateway.server_id,
      target_id: target.server_id,
      source_entity_id: entity.entity_id
    }
  end

  @spec get_network_id(Network.id | nil) ::
    %{network_id: Network.id | nil}
  docp """
  Returns the `network_id` parameter, a subset of the full process params.
  """
  defp get_network_id(network_id = %Network.ID{}),
    do: %{network_id: network_id}
  defp get_network_id(nil),
    do: %{network_id: nil}

  @spec get_bounce_id(Bounce.idt | nil) ::
    %{bounce_id: Bounce.id | nil}
  defp get_bounce_id(nil),
    do: %{bounce_id: nil}
  defp get_bounce_id(%Bounce{bounce_id: bounce_id}),
    do: %{bounce_id: bounce_id}
  defp get_bounce_id(bounce_id = %Bounce.ID{}),
    do: %{bounce_id: bounce_id}

  defp get_resources(executable, resources_params),
    do: call_process(executable, :resources, [resources_params])

  defdelegate setup_connection(args, result, origin, relay),
    to: Executable.Utils

  defdelegate merge_params(params, src_connection, tgt_connection),
    to: Executable.Utils

  defp call_process(executable, method, args) do
    executable
    |> get_process_module()
    |> apply(method, args)
  end

  defp get_process_module(executable) do
    executable
    |> Module.split()
    |> Enum.drop(-1)
    |> Module.concat()
  end

  defp get_executable_hembed(process),
    do: Module.concat(process, :Executable)

  defp get_implemented_callbacks(executable),
    do: executable.__info__(:functions)
end
