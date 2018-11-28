defmodule Helix.Webserver.Router.Macros do

  defmacro route(verb, path, request),
    do: do_route(verb, path, request)

  defp do_route(:get, path, request) do
    quote do
      get unquote(path),
        Helix.Webserver.HelixController,
        :index,
        assigns: %{module: unquote(request)}
    end
  end

  defp do_route(:post, path, request) do
    quote do
      post unquote(path),
        Helix.Webserver.HelixController,
        :index,
        assigns: %{module: unquote(request)}
    end
  end

  defp do_route(:put, path, request) do
    quote do
      put unquote(path),
        Helix.Webserver.HelixController,
        :index,
        assigns: %{module: unquote(request)}
    end
  end

  defp do_route(:delete, path, request) do
    quote do
      delete unquote(path),
        Helix.Webserver.HelixController,
        :index,
        assigns: %{module: unquote(request)}
    end
  end
end
