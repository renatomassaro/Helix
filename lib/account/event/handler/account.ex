defmodule Helix.Account.Event.Handler.Account do

  use Hevent.Handler

  alias Helix.Account.Action.Flow.Account, as: AccountFlow
  alias Helix.Account.Event.Account.Verified, as: AccountVerifiedEvent

  @doc """
  When an account is verified, we must set up its initial server, storyline etc.

  Emits EntityCreatedEvent
  """
  handle AccountVerifiedEvent do
    AccountFlow.setup_account(event.account, event)
  end
end
