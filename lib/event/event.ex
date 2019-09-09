defmodule Helix.Event do

  import HELL.Macros.Docp

  alias Hevent
  alias Helix.Webserver.Request, as: RequestWeb
  alias Helix.Event.Meta, as: EventMeta
  alias Helix.Event.State.Timer, as: EventTimer

  @type t :: struct
  @type source :: t | RequestRelay.t
  @type relay :: source | nil

  @type id :: EventMeta.id

  @spec emit([t] | t, from: t) ::
    term
  @doc """
  Emits an event, inheriting data from the source event passed on the `from`
  parameter. The inherited data is defined at `inherit/2`.
  """
  def emit([], from: _),
    do: :noop
  def emit(events = [_ | _], from: source_event),
    do: Enum.each(events, &emit(&1, from: source_event))
  def emit(event, from: source_event) do
    event
    |> inherit(source_event)
    |> emit()

    # log_event(event)
  end

  @spec emit([t] | t) ::
    term
  @doc """
  Emits an event, or a list of events, through Helix Dispatcher.
  """
  def emit([]),
    do: :noop
  def emit(events = [_|_]),
    do: Enum.each(events, &emit/1)
  def emit(event) do
    Hevent.emit(event)

    #log_event(event)
  end

  @spec emit_after([t] | t, interval :: float | non_neg_integer, from: t) ::
    term
  @doc """
  Emits the given event(s) after `interval` milliseconds have passed.

  It also inherits data from the source event passed on the `from` parameter.
  """
  def emit_after([], _, from: _),
    do: :noop
  def emit_after(events = [_|_], interval, from: source_event),
    do: Enum.each(events, &(emit_after(&1, interval, from: source_event)))
  def emit_after(event, interval, from: source_event) do
    event
    |> inherit(source_event)
    |> emit_after(interval)
  end

  @spec emit_after([t] | t, interval :: float | non_neg_integer) ::
    term
  @doc """
  Emits the given event(s) after `interval` milliseconds have passed.
  """
  def emit_after([], _),
    do: :noop
  def emit_after(events = [_|_], interval),
    do: Enum.each(events, &(emit_after(&1, interval)))
  def emit_after(event, interval),
    do: EventTimer.emit_after(event, interval)

  @spec inherit(t, source) ::
    t
  docp """
  The application wants to emit `event`, which is coming from `source`. On this
  case, `event` will inherit the source's metadata according to the logic below.

  Note that `source` may either be another event (`t`) or a request relay
  (`RequestRelay.t`). If it's a RequestRelay, then this event is being emitted
  as a result of a direct action from the player. On the other hand, if `source`
  is an event, it means this event is a side-effect of another event.
  """
  defp inherit(event, nil),
    do: event
  defp inherit(event, relay = %RequestWeb.Relay{}),
    do: set_request_id(event, relay.request_id)
  defp inherit(event, source) do
    # Relay the `process_id`
    event =
      case get_process_id(source) do
        nil ->
          event

        process_id ->
          set_process_id(event, process_id)
      end

    # Accumulate source event on the stacktrace, and save it on the next event
    stack = get_stack(source) || []
    event = set_stack(event, stack ++ [source.__struct__])

    # Relay the request_id information
    event = set_request_id(event, get_request_id(source))

    # Relay the bounce information
    event = set_bounce_id(event, get_bounce_id(source))

    # Relay the process information
    event = set_process(event, get_process(source))

    # Everything has been inherited, we are ready to emit/1 the event.
    event
  end

  # Delegates the `get_{field}` and `set_{field}` to Helix.Meta
  for field <- EventMeta.meta_fields() do
    defdelegate unquote(:"get_#{field}")(event),
      to: EventMeta
    defdelegate unquote(:"set_#{field}")(event, value),
      to: EventMeta
  end

  @spec generate_id() ::
    id
  @doc """
  Returns a valid UUIDv4 used as event identifier.
  """
  def generate_id,
    do: Ecto.UUID.generate()
end
