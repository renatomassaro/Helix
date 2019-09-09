defmodule Helix.Account.Request.Sync do

  use Helix.Webserver.Request

  import HELL.Macros, only: [hespawn: 1]
  import HELL.Macros.Docp

  alias Helix.Event
  alias Helix.Client.Public.Client, as: ClientPublic
  alias Helix.Core.Validator
  alias Helix.Entity.Model.Entity
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Session.Model.Session
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Server.Public.Index, as: ServerIndex
  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Account.Model.Account
  alias Helix.Account.Henforcer.Sync, as: SyncHenforcer
  alias Helix.Account.Public.Account, as: AccountPublic
  alias __MODULE__.Utils, as: SyncUtils

  alias Helix.Server.Event.Server.Joined, as: ServerJoinedEvent

  def check_params(request, session) do
    with \
      {:ok, client} <- validate_input(request.unsafe["client"], :client)
    do
      reply_ok(request, params: %{client: client})
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, session) do
    resync = session.context[:resync]

    {account_id, session_id} =
      if resync do
        {session.account_id, session.session_id}
      else
        {session.context.account_id, session.context.session_id}
      end

    with \
      {true, r1} <- SyncHenforcer.can_sync?(account_id),
      account = r1.account
    do
      meta = %{account: account, session_id: session_id}
      reply_ok(request, meta: meta)
    else
      {false, reason, _} ->
        forbidden(request, reason)
    end
  end

  def handle_request(request, session) do
    account = request.meta.account
    session_id = request.meta.session_id

    with \
      {:ok, account_sub, servers_subs} <- SyncUtils.subscribe_channels(account),
      {:ok, session_data} <-
        SyncUtils.gather_session_data(request, account_sub, servers_subs),
      {:ok, session} <- SessionAction.create(session_id, session_data)
    do
      meta =
        %{
          session: session,
          account: account,
          subscriptions: %{account: account_sub, servers: servers_subs}
        }

      announce_login(session.socket_data.entity_id, servers_subs)

      reply_ok(request, meta: meta)
    else
      {:error, :internal} ->
        request
        |> destroy_session()
        |> internal_error()

      nil ->
        not_found(request)
    end
  end

  def render_response(request, _session) do
    client = request.params.client
    session_id = request.meta.session.session_id
    account_id = request.meta.account.account_id
    servers_subs = request.meta.subscriptions.servers

    {entity_id, account_bootstrap} = request.meta.subscriptions.account

    # Servers bootstrap
    servers_bootstrap =
      servers_subs
      |> Enum.reduce(%{}, &server_bootstrap_reducer(&1, &2, entity_id))

    # Client bootstrap
    client_bootstrap = ClientPublic.bootstrap(client, entity_id)
    client_bootstrap = ClientPublic.render_bootstrap(client, client_bootstrap)

    reply = %{
      account_id: account_id,
      bootstrap: %{
        account: AccountPublic.render_bootstrap(account_bootstrap),
        servers: servers_bootstrap,
        client: client_bootstrap,
      }
    }

    respond_ok(request, reply)
  end

  defp server_bootstrap_reducer({:gateway, servers}, acc, entity_id) do
    Enum.reduce(servers, acc, fn {server_id, server_bootstrap}, acc ->
      server = ServerQuery.fetch(server_id)
      rendered_bootstrap =
        ServerIndex.render_gateway(server_bootstrap, server, entity_id)

      Map.put(acc, to_string(server_id), rendered_bootstrap)
    end)
  end

  defp server_bootstrap_reducer({:remote, servers}, acc, entity_id) do
    Enum.reduce(servers, acc, fn server_entry, acc ->
      {server_id, server_nip, _gateway_id, server_bootstrap} = server_entry
      #raise "TODO"
      server = ServerQuery.fetch(server_id)
      rendered_bootstrap =
        ServerIndex.render_remote(server_bootstrap, server, entity_id)

      Map.put(acc, stringify_nip(server_nip), rendered_bootstrap)
    end)
  end

  defp stringify_nip({network_id, ip}),
    do: ip <> "@" <> to_string(network_id)

  docp """
  Emits the corresponding `ServerJoinedEvent` for each server that we are
  joining.
  """
  defp announce_login(entity_id, servers_subs) do
    hespawn fn ->

      # TODO: There's a race condition here, hence the `emit_after`. This is
      # obivously a temporary fix. This bug should be documented somewhere.
      Enum.each(servers_subs.gateway, fn {server_id, _} ->
        server_id
        |> ServerJoinedEvent.new(entity_id, :local)
        |> Event.emit_after(3000)
      end)
    end
  end
end
