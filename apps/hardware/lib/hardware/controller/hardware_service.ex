defmodule Helix.Hardware.Controller.HardwareService do

  use GenServer

  alias HELF.Broker
  alias Helix.Hardware.Controller.Motherboard, as: CtrlMobos
  alias Helix.Hardware.Controller.MotherboardSlot, as: CtrlMoboSlots
  alias Helix.Hardware.Controller.Component, as: CtrlComps
  alias Helix.Hardware.Controller.ComponentSpec, as: CtrlCompSpec
  alias Helix.Hardware.Model.MotherboardSlot, as: MotherboardSlot
  alias Helix.Hardware.Model.Component, as: Component
  alias Helix.Hardware.Repo

  @typep state :: nil

  @spec start_link() :: GenServer.on_start
  def start_link do
    GenServer.start_link(__MODULE__, [], name: :hardware)
  end

  @doc false
  def handle_broker_call(pid, "hardware:get", {subject, id}, _request) when is_atom(subject) do
    response = GenServer.call(pid, {subject, :get, id})
    {:reply, response}
  end

  def handle_broker_call(pid, "hardware:get", all_of_kind, _request) when is_atom(all_of_kind) do
    response = GenServer.call(pid, {all_of_kind, :get})
    {:reply, response}
  end

  def handle_broker_call(pid, "hardware:motherboard:create", params, _request) do
    response = GenServer.call(pid, {:motherboard, :create, params})
    {:reply, response}
  end

  def handle_broker_call(pid, "event:server:created", {server_id, _entity_id}, request) do
    GenServer.call(pid, {:setup, server_id, request})
  end

  @spec init(any) :: {:ok, state}
  @doc false
  def init(_args) do
    Broker.subscribe("hardware:get", call: &handle_broker_call/4)
    Broker.subscribe("hardware:motherboard:create", call: &handle_broker_call/4)
    Broker.subscribe("event:server:created", cast: &handle_broker_call/4)

    {:ok, nil}
  end

  @spec handle_call(
    {:motherboard, :create, any},
    GenServer.from,
    state) :: {:reply, {:ok, HELL.PK.t}
              | error :: term, state}
  @spec handle_call(
    {:motherboard, :get, HELL.PK.t},
    GenServer.from,
    state) :: {:reply, {:ok, Helix.Hardware.Model.Motherboard.t}
              | {:error, :notfound}, state}
  @spec handle_call(
    {:motherboard_slot, :get, HELL.PK.t},
    GenServer.from,
    state) :: {:reply, {:ok, Helix.Hardware.Model.MotherboardSlot.t}
              | {:error, :notfound}, state}
  @spec handle_call(
    {:component, :get, HELL.PK.t},
    GenServer.from,
    state) :: {:reply, {:ok, Helix.Hardware.Model.Component.t}
              | {:error, :notfound}, state}
  @spec handle_call(
    {:component_spec, :get, HELL.PK.t},
    GenServer.from,
    state) :: {:reply, {:ok, Helix.Hardware.Model.ComponentSpec.t}
              | {:error, :notfound}, state}
  @spec handle_call(
    {:setup, PK.t, HeBroker.Request.t},
    GenServer.from,
    state) :: {:reply, {:ok | :error}, state}
  @doc false
  def handle_call({:motherboard, :create, params}, _from, state) do
    with {:ok, mobo} <- CtrlMobos.create(params) do
      Broker.cast("hardware:motherboard:created", mobo.motherboard_id)
      {:reply, {:ok, mobo.motherboard_id}, state}
    else
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:motherboard, :get, id}, _from, state) do
    response = CtrlMobos.find(id)
    {:reply, response, state}
  end

  def handle_call({:motherboard_slot, :get, id}, _from, state) do
    response = CtrlMoboSlots.find(id)
    {:reply, response, state}
  end

  def handle_call({:component, :get, id}, _from, state) do
    response = CtrlComps.find(id)
    {:reply, response, state}
  end

  def handle_call({:component_spec, :get, id}, _from, state) do
    response = CtrlCompSpec.find(id)
    {:reply, response, state}
  end

  def handle_call({:setup, server_id, request}, _from, state) do
    result =
      Repo.transaction(fn ->
        with \
          {:ok, motherboard, ev0} <- create_starter_motherboard(),
          {:ok, components, ev1} <- create_starter_components(),
          {:ok, ev2} <- setup_motherboard(motherboard, components)
        do
          {motherboard, ev0 ++ ev1 ++ ev2}
        else
          {:error, _} ->
            Repo.rollback(:internal_error)
        end
      end)

    case result do
      {:ok, {motherboard, events}} ->
        # FIXME: this should be handled by Eventually.flush(events)
        Enum.each(events, fn {topic, params} ->
          Broker.cast(topic, params, request: request)
        end)

        msg = %{
          motherboard_id: motherboard.motherboard_id,
          server_id: server_id}
        Broker.cast("event:motherboard:setup", msg, request: request)

        {:reply, {:ok, motherboard}, state}
      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  @spec create_starter_components() ::
    {:ok, [Component.t], events :: [{String.t, map}]}
    | {:error, Ecto.Changeset.t}
  defp create_starter_components() do
    # FIXME: remove hardcoded components
    [
      {"cpu", "CPU01"},
      {"ram", "RAM01"},
      {"hdd", "HDD01"},
      {"nic", "NIC01"}]
    |> create_components()
    |> case do
      {:ok, components, events} ->
        {:ok, components, events}
      {:error, error} ->
        {:error, error}
    end
  end

  @spec create_starter_motherboard() ::
    {:ok, Motherboard.t, events :: [{String.t, map}]}
    | {:error, Ecto.Changeset.t}
  defp create_starter_motherboard() do
    # FIXME: remove hardcoded motherboard
    with \
      {:ok, component, ev0} <- create_component("mobo", "MOBO01"),
      params = %{motherboard_id: component.component_id},
      {:ok, motherboard} <- CtrlMobos.create(params)
    do
        msg = %{motherboard_id: motherboard.motherboard_id}
        ev1 = {"event:motherboard:created", msg}

        {:ok, motherboard, [ev0, ev1]}
    else
      {:error, error} ->
        {:error, error}
    end
  end

  @spec setup_motherboard(Motherboard.t, [Component.t]) ::
    {:ok, events :: [{String.t, map}]}
    | {:error, :no_slots_available | Ecto.Changeset.t}
  defp setup_motherboard(motherboard, components) do
    grouped_slots =
      motherboard.motherboard_id
      |> CtrlMobos.get_slots()
      |> Enum.reject(&MotherboardSlot.linked?/1)
      |> Enum.group_by(&(&1.link_component_type))

    components
    |> Enum.reduce_while(grouped_slots, fn comp, slots ->
      with \
        [slot | rest] <- Map.get(slots, comp.component_type, []),
        {:ok, _} <- CtrlMoboSlots.link(slot.slot_id, comp.component_id)
      do
        available_slots = Map.put(slots, comp.component_type, rest)
        {:cont, available_slots}
      else
        [] ->
          {:halt, {:error, :no_slots_available}}
        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:error, error} ->
        {:error, error}
      _ ->
        msg = %{motherboard_id: motherboard.motherboard_id}
        {:ok, [{"event:motherboard:created", msg}]}
    end
  end

  @spec create_components([{String.t, String.t}]) ::
    {:ok, [Component.t], events :: [{String.t, map}]}
    | {:error, Ecto.Changeset.t}
  defp create_components(components) do
    create_components(components, {[], []})
  end

  @spec create_components(
    [{String.t, String.t}],
    {[Component.t], [{String.t, map}]}) ::
      {:ok, [Component.t], events :: {String.t, map}}
      | {:error, Ecto.Changeset.t}
  defp create_components([{type, id} | rest], {components, events}) do
    case create_component(type, id) do
      {:ok, component, event} ->
        accum = {[component | components], [event | events]}
        create_components(rest, accum)
      {:error, error} ->
        {:error, error}
    end
  end
  defp create_components([], {components, events}) do
    {:ok, components, events}
  end

  @spec create_component(String.t, String.t) ::
    {:ok, Component.t, event :: {String.t, map}}
    | {:error, Ecto.Changeset.t}
  defp create_component(component_type, spec_id) do
    params = %{
      component_type: component_type,
      spec_id: spec_id}

    case CtrlComps.create(params) do
      {:ok, component} ->
        msg = %{component_id: component.component_id}
        event = {"event:component:created", msg}

        {:ok, component, event}
      {:error, error} ->
        {:error, error}
    end
  end
end