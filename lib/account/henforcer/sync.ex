defmodule Helix.Account.Henforcer.Sync do

  import Helix.Henforcer

  alias Helix.Account.Model.Account
  alias Helix.Account.Henforcer.Account, as: AccountHenforcer

  @type account_syncable_relay :: %{account: Account.t}
  @type account_syncable_relay_partial :: %{}
  @type account_syncable_error ::
    {false, {:account, :not_syncable}, account_syncable_relay_partial}

  @spec account_syncable?(Account.t) ::
    {true, account_syncable_relay}
    | account_syncable_error
  def account_syncable?(%Account{verified: false}),
    do: reply_error({:account, :not_syncable})
  def account_syncable?(%Account{tos_revision: 0}),
    do: reply_error({:account, :not_syncable})
  def account_syncable?(%Account{pp_revision: 0}),
    do: reply_error({:account, :not_syncable})
  def account_syncable?(account = %Account{}),
    do: reply_ok(%{account: account})

  @type can_sync_relay :: %{account: Account.t}
  @type can_sync_relay_partial :: can_sync_relay | %{}
  @type can_sync_error ::
    AccountHenforcer.account_exists_error
    | account_syncable_error

  @spec can_sync?(Account.id) ::
    {true, can_sync_relay}
    | can_sync_error
  def can_sync?(account_id) do
    with \
      {true, r1} <- AccountHenforcer.account_exists?(account_id),
      account = r1.account,
      {true, _} <- account_syncable?(account)
    do
      reply_ok(r1)
    end
  end
end
