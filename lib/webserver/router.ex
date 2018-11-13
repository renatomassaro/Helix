defmodule Helix.Webserver.RouterMacros do

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
end

defmodule Helix.Webserver.Router do
  use Helix.Webserver, :router

  import Helix.Webserver.RouterMacros

  pipeline :api do
    plug :accepts, ["json"]
    plug Helix.Webserver.Plugs.RequestRouter
  end

  scope "/v1", as: :api_v1 do
    pipe_through [:api]

    route(:get, "/", Helix.Request1)
    route(:post, "/login", Helix.Account.Requests.Login)

    scope "/account" do
      post "/join", HelixController, :index
    end

    scope "/server/:server_cid" do
      post "/", HelixController, :index
      post "/join", HelixController, :index
    end
  end
end
