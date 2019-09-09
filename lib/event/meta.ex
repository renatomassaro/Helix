defmodule Helix.Event.Meta do

  alias HELL.HETypes
  alias HELL.Utils
  alias Helix.Event
  alias Helix.Network.Model.Bounce
  alias Helix.Process.Model.Process

  @type t :: %{
    process_id: Process.id | nil,
    process: Process.t | nil,
    stack: [Event.t] | nil,
    request_id: binary | nil,
    bounce_id: Bounce.t | nil
  }

  @type id :: HETypes.uuid

  @type rendered :: %{
    process_id: String.t | nil,
    request_id: binary | nil
  }

  @meta_key :__meta__
  @meta_fields [
    # The `process_id` field is used to identify which process (if any) was
    # responsible for the emission of the current event. Useful to correlate
    # processes side-effects to their process ids on the Client.
    :process_id,

    # Sometimes we have to relay the entire `process`. Note that this should be
    # avoided. If you only need the `process_id`, use that field instead. The
    # reason for this is that's quite likely process will be a stale struct and
    # should not be trusted.
    :process,

    # The `stack` field is a rudimentary stacktrace. Every time an event is
    # emitted from another one, the previous event name is stored on this stack.
    :stack,

    # The `request_id` field associates which request was responsible for this
    # event. Subsequent events will carry on (relay) this request_id as well.
    :request_id,

    # The `bounce_id` field is used to relay bounce information on the event,
    # being notably important for the Loggable protocol, which will rely on the
    # data (or lack thereof) to properly log intermediary hops
    :bounce_id
  ]

  # Generates getters and setters (java feelings)
  for field <- @meta_fields do

    @doc false
    def unquote(:"get_#{field}")(event),
      do: Hevent.get_meta(event, unquote(field))

    @doc false
    def unquote(:"set_#{field}")(event, value) do
      Hevent.set_meta(event, unquote(field), value)
    end
  end

  @doc """
  Returns the key name for the `meta` map.
  """
  def meta_key,
    do: @meta_key

  @doc """
  Returns a list of all fields the `meta` map may have.
  """
  def meta_fields,
    do: @meta_fields

  @spec render(Event.t) ::
    rendered
  @doc """
  Renders the metadata of an event before sending it to the client
  """
  def render(event) do
    %{
      process_id: get_process_id(event) |> Utils.stringify(),
      request_id: get_request_id(event)
    }
  end
end
