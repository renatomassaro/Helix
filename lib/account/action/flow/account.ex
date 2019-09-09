defmodule Helix.Account.Action.Flow.Account do

  import HELF.Flow

  alias Helix.Event
  alias Helix.Entity.Action.Entity, as: EntityAction
  alias Helix.Entity.Model.Entity
  alias Helix.Server.Action.Flow.Motherboard, as: MotherboardFlow
  alias Helix.Server.Action.Flow.Server, as: ServerFlow
  alias Helix.Server.Model.Server
  alias Helix.Account.Action.Account, as: AccountAction
  alias Helix.Account.Action.Email, as: EmailAction
  alias Helix.Account.Model.Account
  alias Helix.Account.Model.Document
  alias Helix.Account.Query.Email, as: EmailQuery

  @spec setup_account(Account.t, Event.relay) ::
    {:ok, %{entity: Entity.t, server: Server.t}}
    | {:error, :internal}
  @doc """
  Setups the input account. Most notably, the initial server.

  Emits EntityCreatedEvent
  """
  def setup_account(acc = %Account{}, relay) do
    flowing do
      with \
        {:ok, entity, events} <- EntityAction.create_from_specialization(acc),
        on_fail(fn -> EntityAction.delete(entity) end),
        # HACK: Workaround for HELF #29
        # on_success(fn -> Event.emit(events, from: relay) end),
        Event.emit(events, from: relay),

        # Create the motherboard and its initial components
        {:ok, motherboard, mobo} <-
           MotherboardFlow.initial_hardware(entity, relay),

        # Create the server and attach the motherboard to it
        {:ok, server} <- ServerFlow.setup(:desktop, entity, mobo, relay),

        # Create a public NetworkConnection and assign it to the mobo (NIC)
        {:ok, _, _} <- MotherboardFlow.isp_connect(entity, motherboard)
      do
        {:ok, %{entity: entity, server: server}}
      else
        _ ->
          {:error, :internal}
      end
    end
  end

  @spec create(Account.email, Account.username, Account.password) ::
    {:ok, Account.t}
    | {:error, Ecto.Changeset.t}
  def create(email, username, password) do
    flowing do
      with \
        {:ok, account, events} <-
          AccountAction.create(email, username, password),
        on_success(fn -> Event.emit(events) end)
      do
        {:ok, account}
      end
    end
  end

  def verify(key) do
    flowing do
      with \
        email_verification = %_{} <- EmailQuery.fetch_verification_by_key(key),
        {:ok, account, events} <- AccountAction.verify(email_verification),
        on_success(fn -> Event.emit(events) end)
      do
        {:ok, account}
      else
        nil ->
          {:error, :wrong_key}
      end
    end
  end

  @spec sign_document(Account.t, Document.t, Document.Signature.info) ::
    {:ok, Account.t}
    | {:error, :internal}
  def sign_document(account, document, info) do
    flowing do
      with \
        {:ok, account, events} <-
          AccountAction.sign_document(account, document, info),
        on_success(fn -> Event.emit(events) end)
      do
        {:ok, account}
      end
    end
  end
end
