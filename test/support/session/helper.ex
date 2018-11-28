# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule Helix.Test.Session.Helper do

  alias Helix.Account.Model.Account
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Session.Model.Session

  alias Helix.Test.Entity.Helper, as: EntityHelper
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Network.Setup, as: NetworkSetup
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Server.Setup, as: ServerSetup

  @internet_id NetworkHelper.internet_id()

  def mock_session!(context, opts \\ []),
    do: mock_session(context, opts) |> elem(0)
  def mock_session(context, opts \\ []) do
    if opts[:with_server],
      do: raise "Use either `with_serverS` or `with_gateway`"

    opts =
      cond do
        opts[:with_servers] ->
          opts
          |> opts_add_gateway()
          |> opts_add_endpoint()

        opts[:with_gateway] ->
          opts_add_gateway(opts)

        :else ->
          opts
          |> Keyword.put_new(:gateway_id, ServerHelper.id())
          |> Keyword.put_new(:gateway_ip, NetworkHelper.ip())
          |> Keyword.put_new(:entity_id, EntityHelper.id())
          |> Keyword.put_new(:endpoint_id, ServerHelper.id())
          |> Keyword.put_new(:endpoint_ip, NetworkHelper.ip())
          |> Keyword.put_new(:endpoint_entity, EntityHelper.id())
      end

    related =
      %{}
      |> Map.merge(opts[:entity] && %{entity: opts[:entity]} || %{})
      |> Map.merge(opts[:gateway] && %{gateway: opts[:gateway]} || %{})
      |> Map.merge(opts[:endpoint] && %{endpoint: opts[:endpoint]} || %{})

    {
      %{
        session_id: Keyword.get(opts, :session_id, id()),
        entity_id: opts[:entity_id],
        account_id: Account.ID.cast!(to_string(opts[:entity_id])),
        client: Keyword.get(opts, :client, :web1),
        context: mock_context(context, opts),
        servers: []
      },
      related
    }
  end

  def mock_context(:server_local, opts) do
    if opts[:server_id],
      do: raise "`server_id` is confusing. Use `gateway_id`."
    if opts[:with_servers],
      do: raise "`server_local` context does not work with `:with_servers`"

    gateway_data =
      %{
        server_id: opts[:gateway_id],
        entity_id: opts[:entity_id]
      }

    %{
      gateway: gateway_data,
      endpoint: gateway_data,
      access: :local
    }
  end

  def mock_context(:server_remote, opts) do
    if opts[:server_id],
      do: raise "Use either `gateway_id` or `endpoint_id`."
    if opts[:server_ip],
      do: raise "Use either `gateway_ip` or `endpoint_ip`."
    if opts[:with_gateway],
      do: raise "`server_remote` context does not work with `:with_gateway`"


    gateway_data =
      %{
        server_id: opts[:gateway_id],
        entity_id: opts[:entity_id],
        ip: opts[:gateway_ip]
      }

    endpoint_data =
      %{
        server_id: opts[:endpoint_id],
        entity_id: opts[:endpoint_entity],
        ip: opts[:endpoint_ip]
      }

    {tunnel, ssh} =
      if opts[:with_servers] do
        tunnel_opts =
          [
            gateway_id: opts[:gateway_id],
            target_id: opts[:endpoint_id],
            network_id: opts[:network_id] || @internet_id,
            fake_servers: true
          ]

        {connection, %{tunnel: tunnel}} =
          NetworkSetup.connection(type: :ssh, tunnel_opts: tunnel_opts)

        session_tunnel =
          %{
            tunnel_id: tunnel.tunnel_id,
            network_id: tunnel.network_id,
            bounce_id: tunnel.bounce_id
          }

        session_connection = %{connection_id: connection.connection_id}

        {session_tunnel, session_connection}
      else
        tunnel =
          %{
            tunnel_id: Keyword.get(opts, :tunnel_id, NetworkHelper.tunnel_id()),
            network_id: Keyword.get(opts, :network_id, @internet_id),
            bounce_id: Keyword.get(opts, :bounce_id, NetworkHelper.bounce_id())
          }

        ssh_id = Keyword.get(opts, :ssh_id, NetworkHelper.connection_id())
        ssh = %{connection_id: ssh_id}

        {tunnel, ssh}
      end

    %{
      gateway: gateway_data,
      endpoint: endpoint_data,
      tunnel: tunnel,
      ssh: ssh,
      access: :remote
    }
  end

  def mock_context(:account, _),
    do: %{}

  def id,
    do: Session.generate_session_id()

  defp opts_add_gateway(opts) do
    {server, %{entity: entity}} = ServerSetup.server()
    server_ip = ServerQuery.get_ip(server, opts[:network_id] || @internet_id)

    opts
    |> Keyword.put(:gateway, server)
    |> Keyword.put(:gateway_id, server.server_id)
    |> Keyword.put(:gateway_ip, server_ip)
    |> Keyword.put(:entity, entity)
    |> Keyword.put(:entity_id, entity.entity_id)
  end

  defp opts_add_endpoint(opts) do
    {server, %{entity: entity}} = ServerSetup.server()
    server_ip = ServerQuery.get_ip(server, opts[:network_id] || @internet_id)

    opts
    |> Keyword.put(:endpoint, server)
    |> Keyword.put(:endpoint_id, server.server_id)
    |> Keyword.put(:endpoint_ip, server_ip)
    |> Keyword.put(:endpoint_entity, entity.entity_id)
  end
end
