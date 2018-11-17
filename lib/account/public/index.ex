defmodule Helix.Account.Public.Index do

  alias Helix.Client.Renderer, as: ClientRenderer
  alias Helix.Entity.Model.Entity
  alias Helix.Entity.Public.Index.Database, as: DatabaseIndex
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Network.Model.Bounce
  alias Helix.Network.Query.Bounce, as: BounceQuery
  alias Helix.Notification.Public.Index.Account, as: AccountNotificationIndex
  alias Helix.Server.Model.Server
  alias Helix.Universe.Bank.Model.BankAccount
  alias Helix.Universe.Bank.Query.Bank, as: BankQuery
  alias Helix.Account.Model.Account
  alias Helix.Account.Public.Index.Inventory, as: InventoryIndex
  alias Helix.Account.Query.Account, as: AccountQuery

  @type index ::
    %{
      mainframe: Server.id,
      inventory: InventoryIndex.index,
      bounces: [Bounce.t],
      database: DatabaseIndex.index,
      bank_accounts: [BankAccount.t],
      notifications: AccountNotificationIndex.index
    }

  @type rendered_index ::
    %{
      mainframe: String.t,
      inventory: InventoryIndex.rendered_index,
      bounces: [ClientRenderer.rendered_bounce],
      database: DatabaseIndex.rendered_index,
      bank_accounts: [rendered_bank_account],
      notifications: AccountNotificationIndex.rendered_index
    }

  @typep rendered_bank_account ::
    %{
      account_number: pos_integer,
      atm_id: String.t,
      password: String.t,
      balance: non_neg_integer
    }

  @spec index(Entity.t) ::
    index
  def index(entity) do
    mainframe =
      entity
      |> EntityQuery.get_servers()
      |> Enum.reverse()
      |> List.first()

    bounces = BounceQuery.get_by_entity(entity)

    account_id = Account.ID.cast!(entity.entity_id |> to_string())

    %{
      profile: AccountQuery.fetch(account_id),
      mainframe: mainframe,
      inventory: InventoryIndex.index(entity),
      bounces: bounces,
      database: DatabaseIndex.index(entity),
      bank_accounts: BankQuery.get_accounts(account_id),
      notifications: AccountNotificationIndex.index(account_id)
    }
  end

  @spec render_index(index) ::
    rendered_index
  def render_index(index) do
    %{
      profile: render_profile(index.profile),
      mainframe: to_string(index.mainframe),
      inventory: InventoryIndex.render_index(index.inventory),
      bounces: Enum.map(index.bounces, &ClientRenderer.render_bounce/1),
      database: DatabaseIndex.render_index(index.database),
      bank_accounts: Enum.map(index.bank_accounts, &render_bank_account/1),
      notifications: AccountNotificationIndex.render_index(index.notifications)
    }
  end

  defp render_profile(profile) do
    %{username: profile.display_name}
  end

  @spec render_bank_account(BankAccount.t) ::
    rendered_bank_account
  defp render_bank_account(bank_account = %BankAccount{}) do
    %{
      account_number: bank_account.account_number,
      atm_id: to_string(bank_account.atm_id),
      password: bank_account.password,
      balance: bank_account.balance
    }
  end
end
