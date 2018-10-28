defmodule Helix.Process.Viewable.Default do

  import HELL.Macros.Docp

  alias HELL.ClientUtils
  alias Helix.Cache.Query.Cache, as: CacheQuery
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Software.Model.File
  alias Helix.Software.Query.File, as: FileQuery
  alias Helix.Process.Model.Process
  alias Helix.Process.Public.View.Process, as: ProcessView

  @spec render(Process.t) ::
    ProcessView.process
  def render(process = %Process{}) do
    progress = build_progress(process)
    usage = build_usage(process)

    source_file = build_file(process.src_file_id)
    target_file = build_file(process.tgt_file_id)

    # OPTIMIZE: Possibly cache `origin_ip` and `target_ip` on the Process.t
    # It's used on several other places and must be queried every time it's
    # displayed.
    origin_ip = get_origin_ip(process)
    target_ip = get_target_ip(process)
    network_id = process.network_id && to_string(process.network_id)

    source_connection_id =
      process.src_connection_id && to_string(process.src_connection_id)
    target_connection_id =
      process.tgt_connection_id && to_string(process.tgt_connection_id)

    %{
      process_id: to_string(process.process_id),
      type: to_string(process.type),
      state: to_string(process.state),
      progress: progress,
      priority: process.priority,
      usage: usage,
      source_file: source_file,
      target_file: target_file,
      origin_ip: origin_ip,
      target_ip: target_ip,
      source_connection_id: source_connection_id,
      target_connection_id: target_connection_id,
      network_id: network_id
    }
  end

  def render_data(_),
    do: %{}

  @spec build_file(File.id | nil) ::
    ProcessView.file
  docp """
  Given the process file ID, builds up the `file` object that will be sent to
  the client.
  """
  defp build_file(nil),
    do: nil
  defp build_file(file_id) do
    file_id
    |> build_file_common()
    |> Map.put(:id, to_string(file_id))
  end

  docp """
  It's possible that a file related to a process has been deleted and the
  relevant process hasn't yet been notified - or never will, in which case it's
  reasonable to have an "Unknown file" as fallback.
  """
  defp build_file_common(file_id) do
    file = FileQuery.fetch(file_id)

    file_name =
      file
      && file.name
      || "Unknown file"

    %{
      name: file_name,
      version: nil
    }
  end

  @spec build_progress(Process.t) ::
    ProcessView.progress
  defp build_progress(process = %Process{}) do
    completion_date =
      if process.completion_date do
        ClientUtils.to_timestamp(process.completion_date)
      else
        nil
      end

    %{
      percentage: process.percentage,
      completion_date: completion_date,
      creation_date: ClientUtils.to_timestamp(process.creation_time)
    }
  end

  @spec build_usage(Process.t) ::
    ProcessView.resources
  defp build_usage(_process = %Process{}) do
    %{
      cpu: %{percentage: 0.0, absolute: 0},
      ram: %{percentage: 0.0, absolute: 0},
      dlk: %{percentage: 0.0, absolute: 0},
      ulk: %{percentage: 0.0, absolute: 0}
    }
  end

  @spec get_target_ip(Process.t) ::
    String.t
  defp get_target_ip(%Process{network_id: nil}),
    do: "localhost"
  defp get_target_ip(process = %Process{}) do
    case CacheQuery.from_server_get_nips(process.target_id) do
      {:ok, nips} ->
        nips
        |> Enum.find(&(&1.network_id == process.network_id))
        |> Map.get(:ip)
        |> to_string()

      {:error, _} ->
        "Unknown IP"
    end
  end

  @spec get_origin_ip(Process.t)
    :: String.t
  defp get_origin_ip(%_{network_id: nil, gateway_id: gtw, target_id: gtw}),
    do: "localhost"
  defp get_origin_ip(%_{network_id: nil}),
    do: "Unknown"
  defp get_origin_ip(%_{network_id: network_id, gateway_id: gateway_id}),
    do: ServerQuery.get_ip(gateway_id, network_id) || "Unknown"
end
