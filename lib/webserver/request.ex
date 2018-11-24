defmodule Helix.Webserver.Request do

  defmacro __using__(_) do
    quote do

      import Helix.Webserver.Request
      import Helix.Webserver.Request.Utils

    end
  end

  def reply_ok(request, opts \\ []) do
    {:ok,
     %{
       meta: Map.merge(request.meta, opts[:meta] || %{}),
       params: Map.merge(request.params, opts[:params] || %{}),
       response: Map.merge(request.response, opts[:response] || %{}),
       status: opts[:status] || request.status,
       __special__: request.__special__
     }
    }
  end

  def reply_error(request, status, reason),
    do: {:error, Map.replace!(request, :status, status), reason}

  def put_special(request, special),
    do: Map.put(request, :__special__, [special | request.__special__])

  def create_session(request, session_id),
    do: put_special(request, %{session_id: session_id, action: :create})
  def destroy_session(request),
    do: put_special(request, %{action: :destroy})
  def start_subscription(request),
    do: put_special(request, %{action: :start_subscription})

  def bad_request(request, reason \\ :bad_request),
    do: reply_error(request, 400, reason)
  def forbidden(request, reason \\ :forbidden),
    do: reply_error(request, 403, reason)
  def not_found(request, reason \\ :not_found),
    do: reply_error(request, 404, reason)
  def internal_error(request, reason \\ :internal),
    do: reply_error(request, 500, reason)

  def respond(request, status, response),
    do: {:ok, %{request| response: response, status: status}}
  def respond_ok(request, response),
    do: respond(request, 200, response)
  def respond_created(request, response),
    do: respond(request, 201, response)
  def respond_empty(request, status \\ 200),
    do: respond(request, status, %{})
end
