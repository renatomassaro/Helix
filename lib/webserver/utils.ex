defmodule Helix.Webserver.Utils do

  def reply_ok(request, opts \\ []) do
    {:ok,
     %{
       meta: Map.merge(request.meta, opts[:meta] || %{}),
       params: Map.merge(request.params, opts[:params] || %{}),
       response: Map.merge(request.response, opts[:response] || %{}),
       status: opts[:status] || request.status
     }
    }
  end

  def reply_error(request, status, reason),
    do: {:error, Map.replace!(request, :status, status), reason}

  def bad_request(request, reason \\ :bad_request),
    do: reply_error(request, 400, reason)
  def forbidden(request, reason \\ :forbidden),
    do: reply_error(request, 403, reason)

  def respond(request, status, response),
    do: {:ok, %{request| response: response, status: status}}
  def respond_ok(request, response),
    do: respond(request, 200, response)
  def respond_created(request, response),
    do: respond(request, 201, response)
  def respond_empty(request, status \\ 200),
    do: respond(request, status, %{})
end
