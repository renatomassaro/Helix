defmodule Helix.Test.Session.Setup do

  alias Helix.Account.Request.Sync, as: SyncRequest
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Server.Public.Server, as: ServerPublic
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Session.Query.Session, as: SessionQuery

  alias Helix.Test.Account.Setup, as: AccountSetup
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Network.Setup, as: NetworkSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper

  @internet_id NetworkHelper.internet_id()
  @relay nil

  @doc """
  """
  def create(local: local_opts, remote: remote_opts),
    do: create(local: local_opts, remote: remote_opts, meta: [])
  def create(local: local_opts, remote: remote_opts, meta: meta_opts) do
    local_config = create_config(local_opts, true)
    remote_config = create_config(remote_opts, false)

    bounce =
      if remote_opts[:with_bounce] do
        NetworkSetup.Bounce.bounce!(
          total: 3, entity_id: local_config.entity.entity_id
        )
      else
          nil
      end

    unless is_nil(remote_config) do
      network_id = Keyword.get(remote_opts, :network_id, @internet_id)

      # Setup SSH connection between gateway and endpoint
      {:ok, _, _} =
        ServerPublic.connect_to_server(
          network_id,
          local_config.gateway.server_id,
          remote_config.endpoint.server_id,
          bounce,
          @relay
        )
    end

    # Generate unsynced session for local account
    {:ok, unsynced_session} =
      SessionAction.create_unsynced(local_config.account.account_id)

    if meta_opts[:skip_sync] do
      context =
        unsynced_session
        |> Map.from_struct()
        |> Map.merge(%{resync: false})

      %{
        session: unsynced_session,
        context: context,
        local: local_config,
        remote: remote_config,
        bounce: bounce
      }
    else
      # Force fetch so it goes through the internal formatting process
      unsynced_session = SessionQuery.fetch_unsynced(unsynced_session.session_id)

      # Synchronize the session
      {:ok, _} = sync_request(%{context: unsynced_session})

      session = SessionQuery.fetch(unsynced_session.session_id)
      context = get_context(session, local_config, remote_config)

      %{
        session: session,
        context: context,
        local: local_config,
        remote: remote_config,
        bounce: bounce
      }
    end
  end

  def create(local: local_opts),
    do: create(local: local_opts, remote: nil)
  def crete(bogus_opts),
    do: raise "`local:` keyword required on SessionSetup.create opts"

  @doc """
  - with_server: Whether the account should have a server attached to it.
  Defaults to true.
  """
  def create_local(opts \\ []) do
    with_server? = Keyword.get(opts, :with_server, true)
    account = AccountSetup.account!(with_server: with_server?)

    create(local: [account: account])
  end

  def create_local!(opts \\ []),
    do: create_local(opts) |> Map.fetch!(:session)

  @doc """
  """
  def create_remote(opts \\ []) do
    local_account = AccountSetup.account!(with_server: true)
    remote_account = AccountSetup.account!(with_server: true)

    local_base_opts = [account: local_account]
    remote_base_opts = [account: remote_account]

    local_opts = local_base_opts
    remote_opts =
      if opts[:with_bounce] do
        remote_base_opts ++ [with_bounce: true]
      else
        remote_base_opts
      end

    create(local: local_opts, remote: remote_opts)
  end

  def create_remote!(opts \\ []),
    do: create_remote(opts) |> Map.fetch!(:session)

  def create_unsynced(opts \\ []) do
    {account, account_id} =
      if opts[:account_id] do
        {nil, opts[:account_id]}
      else
        account = AccountSetup.account!()
        {account, account.account_id}
      end

    {:ok, unsynced_session} = SessionAction.create_unsynced(account_id)

    {unsynced_session, %{account: account}}
  end

  defp create_config(nil, _),
    do: nil
  defp create_config(opts, local?) do
    account =
      if opts[:account] do
        opts[:account]
      else
        AccountSetup.account!(with_server: true)
      end

    entity =
      account.account_id
      |> EntityQuery.get_entity_id()
      |> EntityQuery.fetch()

    servers =
      entity
      |> EntityQuery.get_servers()
      |> Enum.map(&ServerQuery.fetch/1)

    mainframe = Enum.find(servers, &(&1.type == :desktop))

    mainframe_key =
      if local? do
        :gateway
      else
        :endpoint
      end

    %{
      account: account,
      servers: servers,
      entity: entity
    }
    |> Map.put(mainframe_key, mainframe)
  end

  defp get_context(session, local_config, nil),
    do: session.servers[local_config.gateway.server_id |> to_string()]
  defp get_context(session, _, remote_config),
    do: session.servers[remote_config.endpoint.server_id |> to_string()]

  defp sync_request(session) do
    request = RequestHelper.mock_request(unsafe: %{"client" => "web1"})
    RequestHelper.execute_until(SyncRequest, :handle_request, request, session)
  end
end