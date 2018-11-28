defmodule Helix.Test.Session.Setup do

  alias Helix.Account.Request.Sync, as: SyncRequest
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Server.Public.Server, as: ServerPublic
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Session.Query.Session, as: SessionQuery

  alias Helix.Test.Account.Setup, as: AccountSetup
  alias Helix.Test.Network.Helper, as: NetworkHelper

  @internet_id NetworkHelper.internet_id()
  @relay nil

  @doc """
  """
  def create(local: local_opts, remote: remote_opts) do
    local_config = create_config(local_opts, true)
    remote_config = create_config(remote_opts, false)

    unless is_nil(remote_config) do
      network_id = Keyword.get(remote_opts, :network_id, @internet_id)
      bounce = Keyword.get(remote_opts, :bounce, nil)

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

    # Force fetch so it goes through the internal formatting process
    unsynced_session = SessionQuery.fetch_unsynced(unsynced_session.session_id)

    # Synchronize the session
    SyncRequest.handle_request(
      mock_request(params: %{client: :web1}), %{context: unsynced_session}
    )

    session = SessionQuery.fetch(unsynced_session.session_id)
    context = get_context(session, local_config, remote_config)

    %{
      session: session,
      context: context,
      local: local_config,
      remote: remote_config
    }
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

    create(local: [account: local_account], remote: [account: remote_account])
  end

  def create_remote!(opts \\ []),
    do: create_remote(opts) |> Map.fetch!(:session)

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

  # TODO: Belongs elsewhere
  defp mock_request(opts) do
    %{
      meta: opts[:meta] || %{},
      params: opts[:params] || %{},
      response: opts[:response] || %{},
      status: opts[:status] || nil,
      relay: opts[:relay] || nil,
      __special__: []
    }
  end
end
