defmodule Helix.Event.Trigger.Loggable do

  import HELL.Macros.Docp

  alias Hevent.Trigger

  alias Helix.Event
  alias Helix.Event.Loggable.Utils, as: LoggableUtils
  alias Helix.Entity.Model.Entity
  alias Helix.Log.Model.Log
  alias Helix.Log.Model.LogType
  alias Helix.Log.Action.Log, as: LogAction
  alias Helix.Network.Model.Bounce
  alias Helix.Network.Model.Network
  alias Helix.Network.Model.Tunnel
  alias Helix.Network.Query.Bounce, as: BounceQuery
  alias Helix.Server.Model.Server

  @type log_entry ::
    {Server.id, Entity.id, Log.info}

  @trigger Loggable

  @doc """
  Handler for all events that implement the Loggable trigger.
  """
  def flow(event) do
    event
    |> Trigger.get_data(:log_map, @trigger)
    |> handle_map()
    |> generate_entries()
    |> save()
    |> Event.emit(from: event)
  end

  @doc false
  def handle_map(empty_map) when map_size(empty_map) == 0,
    do: empty_map
  def handle_map(log_map) do
    log_map

    # Put default values (when not specified)
    |> Map.put_new(:network_id, nil)
    |> Map.put_new(:endpoint_id, nil)
    |> Map.put_new(:data_both, %{})
    |> Map.put_new(:opts, %{})
  end

  @doc """
  Matches against the most common `log_map` format, i.e. a log that will be
  created on both `gateway` and `endpoint`, as well as all servers between them,
  as defined on the bounce (inherited from `event`).
  """
  def generate_entries(
    %{
      event: event,
      entity_id: entity_id,
      gateway_id: gateway_id,
      endpoint_id: endpoint_id,
      network_id: network_id,
      type_gateway: type_gateway,
      data_gateway: data_gateway,
      type_endpoint: type_endpoint,
      data_endpoint: data_endpoint,
      data_both: data_both,
      opts: opts
    })
  do
    skip_bounce? = Map.get(opts, :skip_bounce, false)

    bounce_id = Event.get_bounce_id(event)
    bounce =
      if bounce_id do
        BounceQuery.fetch(bounce_id)
      else
        nil
      end

    gateway_ip = get_ip(gateway_id, network_id)
    endpoint_ip = get_ip(endpoint_id, network_id)

    first_ip =
      if skip_bounce? do
        endpoint_ip
      else
        get_first_ip(bounce, endpoint_ip)
      end
      |> customize_first_ip(opts)

    last_ip =
      if skip_bounce? do
        gateway_ip
      else
        get_last_ip(bounce, gateway_ip)
      end
      |> customize_last_ip(opts)

    data_gateway =
      data_gateway
      |> replace_ips(first_ip, last_ip)
      |> Map.merge(data_both)

    data_endpoint =
      data_endpoint
      |> replace_ips(first_ip, last_ip)
      |> Map.merge(data_both)

    log_gateway = {type_gateway, LogType.new(type_gateway, data_gateway)}
    log_endpoint = {type_endpoint, LogType.new(type_endpoint, data_endpoint)}

    entry_gateway = build_entry(gateway_id, entity_id, log_gateway)
    entry_endpoint = build_entry(endpoint_id, entity_id, log_endpoint)

    bounce_entries =
      if skip_bounce? do
        []
      else
        build_bounce_entries(
          bounce,
          {gateway_id, network_id, gateway_ip},
          {endpoint_id, network_id, endpoint_ip},
          entity_id,
          network_id
        )
      end

    [entry_gateway, entry_endpoint, bounce_entries] |> List.flatten()
  end

  @doc """
  Event requested to create a single log on the server, meaning this log has no
  influence whatsoever from a remote endpoint, a bounce, a network etc. It's an
  "offline" log.
  """
  def generate_entries(
    %{
      event: _,
      server_id: server_id,
      entity_id: entity_id,
      type: type,
      data: data
    })
  do
    log_type = LogType.new(type, data)

    [build_entry(server_id, entity_id, {type, log_type})]
  end

  @doc """
  Fallback (empty log)
  """
  def generate_entries(empty_map) when map_size(empty_map) == 0,
    do: []

  defdelegate get_file_name(file),
    to: LoggableUtils

  defdelegate get_ip(server_id, network_id),
    to: LoggableUtils

  defdelegate censor_ip(ip),
    to: LoggableUtils

  defdelegate format_ip(ip),
    to: LoggableUtils

  @spec build_entry(Server.id, Entity.id, Log.info) ::
    log_entry
  @doc """
  Returns data required to insert the log
  """
  def build_entry(server_id, entity_id, msg),
    do: {server_id, entity_id, msg}

  @doc """
  Generates the `log_entry` list for all nodes between the gateway and the
  endpoint, i.e. all hops on the bounce.

  Messages follow the format "Connection bounced from hop (n-1) to (n+1)"
  """
  def build_bounce_entries(nil, _, _, _, _),
    do: []
  def build_bounce_entries(
    bounce_id = %Bounce.ID{}, gateway, endpoint, entity, network
  ) do
    bounce_id
    |> BounceQuery.fetch()
    |> build_bounce_entries(gateway, endpoint, entity, network)
  end

  def build_bounce_entries(
    bounce = %Bounce{},
    gateway = {_, _, _},
    endpoint = {_, _, _},
    entity_id,
    network_id
  ) do
    full_path = [gateway | bounce.links] ++ [endpoint]
    length_hop = length(full_path)

    # Create a map of the bounce route, so we can access each entry based on
    # their (sequential) index
    bounce_map =
      full_path
      |> Enum.reduce({0, %{}}, fn link, {idx, acc} ->
        {idx + 1, Map.put(acc, idx, link)}
      end)
      |> elem(1)

    full_path
    |> Enum.reduce({0, []}, fn {server_id, _, _}, {idx, acc} ->

      # Skip first and last hops, as they are both the `gateway` and `endpoint`,
      # and as such have a custom log message.
      if idx == 0 or idx == length_hop - 1 do
        {idx + 1, acc}

      # Otherwise, if it's an intermediary server, we generate the bounce msg
      else
        {_, _, ip_prev} = bounce_map[idx - 1]
        {_, _, ip_next} = bounce_map[idx + 1]

        data = %{ip_prev: ip_prev, ip_next: ip_next, network_id: network_id}
        log_info = {:connection_bounced, LogType.new(:connection_bounced, data)}

        entry = build_entry(server_id, entity_id, log_info)

        {idx + 1, acc ++ [entry]}
      end
    end)
    |> elem(1)
  end

  @spec save([log_entry] | log_entry) ::
    [Event.t]
  @doc """
  Receives the list of generated entries, which is returned by each event that
  implements the Loggable trigger, and inserts them into the game database.
  Accumulates the corresponding `LogCreatedEvent`s, which shall be emitted by
  the caller.
  """
  def save([]),
    do: []
  def save(log_entry = {_, _, _}),
    do: save([log_entry])
  def save(logs) do
    logs
    |> Enum.map(fn {server_id, entity_id, log_type} ->
      {:ok, _, events} = LogAction.create(server_id, entity_id, log_type)
      events
    end)
    |> List.flatten()
  end

  @spec get_first_ip(Tunnel.bounce, Network.ip) ::
    Network.ip
  @doc """
  Returns the "first ip". The "first ip" is the IP address that should be
  displayed on the first log entry of the log chain. When there's no bounce, the
  first IP is the victim's (target) IP. If there's a bounce, the first IP is the
  bounce's first hop IP.
  """
  def get_first_ip(nil, ip),
    do: format_ip(ip)
  def get_first_ip(bounce = %Bounce{}, _) do
    [{_, _first_hop_network, first_hop_ip} | _] = bounce.links

    format_ip(first_hop_ip)
  end

  @spec get_last_ip(Tunnel.bounce, Network.ip) ::
    Network.ip
  @doc """
  Returns the "last ip". The "last ip" is the IP address that should be
  displayed on the last log entry of the log chain. When there's no bounce, the
  last IP is the attacker's (gateway) IP. If there's a bounce, the last IP is
  the bounce's last hop IP.
  """
  def get_last_ip(nil, ip),
    do: format_ip(ip)
  def get_last_ip(bounce = %Bounce{}, _) do
    [{_, _last_hop_network, last_hop_ip} | _] = Enum.reverse(bounce.links)
    format_ip(last_hop_ip)
  end

  @spec customize_first_ip(Network.ip, map) ::
    Network.ip
  docp """
  Customizes the first IP according to the log_map opts.
  """
  defp customize_first_ip(ip, %{censor_first: true}),
    do: censor_ip(ip)
  defp customize_first_ip(ip, _),
    do: ip

  @spec customize_last_ip(Network.ip, map) ::
    Network.ip
  docp """
  Customizes the last IP according to the log_map opts.
  """
  defp customize_last_ip(ip, %{censor_last: true}),
    do: censor_ip(ip)
  defp customize_last_ip(ip, _),
    do: ip

  defp replace_ips(params, first_ip, last_ip) do
    params
    |> Enum.reduce([], fn {k, v}, acc ->
      new_v =
        case v do
          "$first_ip" ->
            first_ip

          "$last_ip" ->
            last_ip

          _ ->
            v
        end

      [{k, new_v} | acc]
    end)
    |> Enum.into(%{})
  end
end
