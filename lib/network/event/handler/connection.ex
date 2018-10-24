defmodule Helix.Network.Event.Handler.Connection do

  use Hevent.Handler

  alias Helix.Event
  alias Helix.Network.Action.Tunnel, as: TunnelAction
  alias Helix.Network.Query.Tunnel, as: TunnelQuery

  alias Helix.Universe.Bank.Event.Bank.Transfer.Processed,
    as: BankTransferProcessedEvent

  handle BankTransferProcessedEvent do
    connection = TunnelQuery.fetch_connection(event.connection_id)
    close_event = TunnelAction.close_connection(connection)
    Event.emit(close_event, from: event)
  end
end
