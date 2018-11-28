defmodule Helix.Log.Request.Paginate do

  use Helix.Webserver.Request

  alias Helix.Log.Model.Log
  alias Helix.Log.Query.Log, as: LogQuery
  alias Helix.Log.Public.Index, as: LogIndex

  @default_total 20
  @max_total 100

  def check_params(request, _session) do
    with {:ok, log_id} <- Log.ID.cast(request.unsafe["log_id"]) do
      params = %{
        log_id: log_id,
        total: get_total(request.unsafe["total"])
      }

      reply_ok(request, params: params)
    else
      _ ->
        bad_request(request)
    end
  end

  defp get_total(total) when not is_integer(total),
    do: @default_total
  defp get_total(total) when total <= 0,
    do: @default_total
  defp get_total(total) when total >= @max_total,
    do: @max_total
  defp get_total(total),
    do: total

  def check_permissions(request, _session),
    do: reply_ok(request)

  def handle_request(request, session) do
    server_id = session.context.endpoint.server_id
    log_id = request.params.log_id
    total = request.params.total

    logs = LogQuery.paginate_logs_on_server(server_id, log_id, total)

    reply_ok(request, meta: %{logs: logs})
  end

  def render_response(request, _session) do
    logs = Enum.map(request.meta.logs, &LogIndex.render_log/1)

    respond_ok(request, logs)
  end
end
