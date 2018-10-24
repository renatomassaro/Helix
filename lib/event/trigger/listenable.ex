defmodule Helix.Event.Trigger.Listenable do

  alias Hevent.Trigger

  alias Helix.Event
  alias Helix.Core.Listener.Model.Listener
  alias Helix.Core.Listener.Query.Listener, as: ListenerQuery

  @trigger Listenable

  @spec flow(Event.t) ::
    term
  @doc """
  `flow/1` is responsible for listening to all events and that implement the
  `Listenable` trigger, and it will check if there are any services subscribed
  to that specific event under that specific object ID.
  """
  def flow(event) do
    # OPTIMIZE: There's room for optimization on this function. Some events may
    # return several objects on `Listenable.get_objects/0`, and currently we
    # perform a separate query for each one. Instead, fetching all matching
    # objects with `IN`, and filtering by `event.__struct__` within the
    # application would yield a faster operation.
    event
    |> Trigger.get_data(:get_objects, @trigger)
    |> Enum.each(fn object_id -> find_listeners(object_id, event) end)
  end

  @spec find_listeners(Listener.object_id, Event.t) ::
    term
  defp find_listeners(object_id, event) do
    object_id
    |> ListenerQuery.get_listeners(event.__struct__)
    |> Enum.each(fn listener -> execute_callback(listener, event) end)
  end

  @spec execute_callback(Listener.info, Event.t) ::
    term
  defp execute_callback(%{module: module, method: method, meta: meta}, event) do
    module = String.to_atom(module)
    method = String.to_atom(method)

    params =
    if meta do
      [event, meta]
    else
      [event]
    end

    {:ok, events} = apply(module, method, params)

    Event.emit(events, from: event)
  end
end
