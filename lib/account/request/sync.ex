defmodule Helix.Account.Request.Sync do

  import Helix.Webserver.Request

  alias Helix.Client.Public.Client, as: ClientPublic
  alias Helix.Core.Validator
  alias Helix.Entity.Model.Entity
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Session.Model.Session
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Server.Public.Index, as: ServerIndex
  alias Helix.Session.Action.Session, as: SessionAction
  alias Helix.Account.Model.Account
  alias Helix.Account.Query.Account, as: AccountQuery
  alias Helix.Account.Public.Account, as: AccountPublic

  def check_params(request, session) do
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
    resync = session.context[:resync]

    {account_id, session_id} =
      if resync do
        {session.account_id, session.session_id}
      else
        {session.context.account_id, session.context.session_id}
      end

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
      {:error, :internal} ->
        request
        |> destroy_session()
        |> internal_error()

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
    {gateway_subs, endpoints_map} =
      account_bootstrap.servers.player
      |> Enum.reduce({[], %{}}, fn sub, {acc_subs, acc_map} ->
        server_sub =
          sub.server.server_id
          |> ServerQuery.fetch()
          |> ServerIndex.gateway(entity_id)

        endpoints_map =
          sub.endpoints
          |> Enum.reduce(acc_map, fn %{network_id: network_id, ip: ip}, acc ->
            Map.put(acc, {network_id, ip}, sub.server.server_id)
          end)

        {[{sub.server.server_id, server_sub} | acc_subs], endpoints_map}
      end)

    remote_subs =
      account_bootstrap.servers.remote
      |> Enum.reduce([], fn %{ip: ip, network_id: network_id}, acc ->
        server = ServerQuery.fetch_from_nip(network_id, ip)
        server_nip = {network_id, ip}
        gateway_id = endpoints_map[server_nip]
        server_sub = ServerIndex.remote(server, gateway_id, entity_id)

        [{server.server_id, server_nip, gateway_id, server_sub} | acc]
      end)

    {:ok, acc_sub, %{gateway: gateway_subs, remote: remote_subs}}
  end

  defp gather_session_data(request, {entity_id, account_boot}, servers_subs) do
    socket_data = build_socket_data(entity_id, request.params.client)

    account_data = %{}

    servers_gateway_data =
      servers_subs.gateway
      |> Enum.reduce(%{}, fn local_sub = {server_id, _}, acc ->
        server_data = build_server_data(:local, entity_id, local_sub)
        Map.put(acc, server_id, server_data)
      end)
      |> Enum.into(%{})

    servers_remote_data =
      servers_subs.remote
      |> Enum.reduce(%{}, fn remote_sub = {server_id, _, _, _}, acc ->
        server_data =
          build_server_data(
            :remote, entity_id, remote_sub, servers_subs.gateway
          )

        Map.put(acc, server_id, server_data)
      end)

    servers_data = Map.merge(servers_gateway_data, servers_remote_data)

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

  defp build_socket_data(entity_id, client) do
    %{
      account_id: Account.ID.cast!(to_string(entity_id)),
      entity_id: entity_id,
      session_id: :placeholder,
      client: client
    }
  end

  defp build_server_data(:local, entity_id, {server_id, server_boot}) do
    %{
      server_id: server_id,
      entity_id: entity_id,
      access: :local
    }
  end

  # TODO: Maybe move `buld_*` to SessionModel
  # After all, remote_sub, gateawy_sub etc etc types will be at SessionModel
  defp build_server_data(:remote, entity_id, remote_sub, gateway_subs) do
    {endpoint_id, {network_id, ip}, gateway_id, server_boot} = remote_sub

    tunnel =
      server_boot.tunnels.target
      |> Enum.find(&(&1.gateway_id == gateway_id))

    ssh = Enum.find(tunnel.connections, &(&1.connection_type == :ssh))

    {_, gateway_boot} =
      Enum.find(gateway_subs, fn {server_id, _} ->
        server_id == gateway_id
      end)

    %{ip: gateway_ip} =
      Enum.find(gateway_boot.nips, &(&1.network_id == network_id))

    gateway_data = %{
      server_id: gateway_id,
      entity_id: entity_id,
      ip: gateway_ip
    }

    endpoint_data = %{
      server_id: endpoint_id,
      entity_id: EntityQuery.fetch_by_server(endpoint_id).entity_id,
      ip: ip
    }

    %{
      gateway: gateway_data,
      endpoint: endpoint_data,
      tunnel: Session.format_tunnel(tunnel),
      ssh: Session.format_ssh(ssh),
      access: :remote
    }
  end
end
