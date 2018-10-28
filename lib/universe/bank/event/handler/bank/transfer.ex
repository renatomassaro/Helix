defmodule Helix.Universe.Bank.Event.Handler.Bank.Transfer do

  use Hevent.Handler

  alias Helix.Universe.Bank.Action.Bank, as: BankAction
  alias Helix.Universe.Bank.Query.Bank, as: BankQuery
  alias Helix.Universe.Bank.Event.Bank.Transfer.Aborted,
    as: BankTransferAbortedEvent
  alias Helix.Universe.Bank.Event.Bank.Transfer.Processed,
    as: BankTransferProcessedEvent

  def handle_event(event = %BankTransferProcessedEvent{}) do
    transfer = BankQuery.fetch_transfer(event.transfer_id)
    BankAction.complete_transfer(transfer)
  end

  def handle_event(event = %BankTransferAbortedEvent{}) do
    transfer = BankQuery.fetch_transfer(event.transfer_id)
    BankAction.abort_transfer(transfer)
  end
end
