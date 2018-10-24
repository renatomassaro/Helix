defmodule Helix.Test.Event.Helper.Trigger.Publishable do

  alias Hevent.Trigger

  @trigger Publishable

  @doc false
  def generate_payload(event, socket),
    do: Trigger.get_data([event, socket], :generate_payload, @trigger)

  @doc false
  def get_event_name(event),
    do: Trigger.get_data(event, :event_name, @trigger)

  @doc false
  def whom_to_publish(event),
    do: Trigger.get_data(event, :whom_to_publish, @trigger)
end
