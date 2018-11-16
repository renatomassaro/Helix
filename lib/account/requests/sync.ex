defmodule Helix.Account.Requests.Sync do

  import Helix.Webserver.Utils

  alias Helix.Client.Public.Client, as: ClientPublic
  alias Helix.Core.Validator
  alias Helix.Entity.Model.Entity
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Server.Public.Index, as: ServerIndex
  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Account.Model.Account
  alias Helix.Account.Query.Account, as: AccountQuery
  alias Helix.Account.Public.Account, as: AccountPublic

  def check_params(request, _session) do
    with \
      {:ok, client} <-
        Validator.validate_input(request.unsafe["client"], :client)
    do
      reply_ok(request, params: %{client: client})
    else
      _ ->
        bad_request(request)
    end
  end

  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, session) do
    account_id = session.context.account_id
    session_id = session.context.session_id

    with \
      account = %_{} <- AccountQuery.fetch(account_id),
      {:ok, account_sub, servers_subs} <- subscribe_channels(account),
      {:ok, session_data} <-
        gather_session_data(request, account_sub, servers_subs),
      {:ok, session} <- SessionAction.create(session_id, session_data)
    do
      meta =
        %{
          session: session,
          account: account,
          subscriptions: %{account: account_sub, servers: servers_subs}
        }

      reply_ok(request, meta: meta)
    else
      nil ->
        not_found(request)
    end
  end

  defp subscribe_channels(account) do
    account
    |> subscribe_account()
    |> subscribe_servers()
  end

  defp subscribe_account(account) do
    entity_id = Entity.ID.cast!(to_string(account.account_id))

    account_bootstrap = AccountPublic.bootstrap(entity_id)

    {:ok, {entity_id, account_bootstrap}, []}
  end

  defp subscribe_servers({:ok, acc_sub = {entity_id, account_bootstrap}, _}) do
    # TODO: Remote
    servers_subs =
      account_bootstrap.servers.player
      |> Enum.reduce([], fn %{server: server}, acc ->
        server_sub =
          server.server_id
          |> ServerQuery.fetch()
          |> ServerIndex.gateway(entity_id)

        [{server.server_id, server_sub} | acc]
      end)

    {:ok, acc_sub, %{gateway: servers_subs, remote: %{}}}
  end

  defp gather_session_data(request, {entity_id, account_boot}, servers_subs) do
    socket_data =
      %{
        account_id: Account.ID.cast!(to_string(entity_id)),
        entity_id: entity_id,
        session_id: :placeholder,
        client: request.params.client
      }

    account_data = %{}

    servers_data =
      servers_subs.gateway
      |> Enum.reduce(%{}, fn {server_id, server_boot}, acc ->
        gateway_data = %{server_id: server_id, entity_id: entity_id}
        server_data =
          %{
            gateway: gateway_data,
            endpoint: gateway_data,
            meta: %{access: :local}
          }

        Map.put(acc, server_id, server_data)
      end)
      |> Enum.into(%{})

    {:ok, %{socket: socket_data, account: account_data, servers: servers_data}}
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
      session_id: session_id,
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
    Enum.reduce(servers, acc, fn {server_id, server_bootstrap}, acc ->
      raise "TODO"
      server = ServerQuery.fetch(server_id)
      rendered_bootstrap =
        ServerIndex.render_remote(server_bootstrap, server, entity_id)

      Map.put(acc, to_string(server_id), rendered_bootstrap)
    end)
  end
end
