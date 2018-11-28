defmodule Helix.Test.Webserver.Request.Helper do

  @methods [
    :check_params,
    :check_permissions,
    :handle_request,
    :render_response
  ]

  def check_params(module, request, session),
    do: execute_until(module, :check_params, request, session)
  def check_permissions(module, request, session),
    do: execute_until(module, :check_permissions, request, session)
  def handle_request(module, request, session),
    do: execute_until(module, :handle_request, request, session)
  def render_response(module, request, session),
    do: execute_until(module, :render_response, request, session)

  def execute(module, method, request, session),
    do: apply(module, method, [request, session])

  def execute_until(module, final_method, req, session) do
    @methods
    |> Enum.reduce({nil, req, false}, fn cur_method, {result, acc_req, stop?} ->
      if stop? do
        {result, acc_req, stop?}
      else
        case execute(module, cur_method, acc_req, session) do
          response = {:ok, new_req} ->
            {response, new_req, cur_method == final_method}

          response = {:error, _, _} ->
            {response, acc_req, true}
        end
      end
    end)
    |> elem(0)
  end

  def mock_request(opts \\ []) do
    if opts[:params],
      do: raise "`:params` is invalid. Use either `:unsafe` or `:req_params`"

    unsafe_params =
      Map.merge(
        Keyword.get(opts, :unsafe, %{}),
        Keyword.get(opts, :url_params, %{})
      )

    %{
      unsafe: unsafe_params,
      params: Keyword.get(opts, :req_params, %{}),
      meta: %{},
      response: %{},
      status: nil,
      relay: nil,
      __special__: []
    }
  end
end
