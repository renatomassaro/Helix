# # TODO: This whole module needs to be rewritten with the new Process interface.
defmodule Helix.Software.Model.SoftwareType.Firewall.Passive do

#   @type t :: %__MODULE__{
#     version: pos_integer
#   }

#   @enforce_keys [:version]
#   defstruct [:version]

#   defimpl Helix.Process.Model.Processable do

#     alias Helix.Software.Event.Firewall.Stopped, as: FirewallStoppedEvent

#     def kill(data, process, _) do
#       event = %FirewallStoppedEvent{
#         version: data.version,
#         gateway_id: process.gateway_id
#       }

#       {:delete, [event]}
#     end

#     def complete(data, process) do
#       event = %FirewallStoppedEvent{
#         version: data.version,
#         gateway_id: process.gateway_id
#       }

#       {:delete, [event]}
#     end

#     def retarget(_, _) do
#       {:noop, []}
#     end

#     def source_connection_closed(_, _, _) do
#       {:delete, []}
#     end

#     def target_connection_closed(_, _, _) do
#       {:delete, []}
#     end

#     def target_log_revised(_, _, _) do
#       {:noop, []}
#     end

#     def target_log_recovered(_, _, _) do
#       {:noop, []}
#     end

#     def target_log_destroyed(_, _, _) do
#       {:noop, []}
#     end

#     def after_read_hook(data),
#       do: data
#   end
end
