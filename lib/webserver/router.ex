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
    plug :accepts, ["json", "txt"]
    plug Helix.Webserver.Plugs.Entrypoint
    plug Helix.Webserver.Plugs.CSRFHandler
    plug Helix.Webserver.Plugs.SessionHandler
    plug Helix.Webserver.Plugs.RequestRouter
  end

  scope "/v1", as: :api_v1 do
    pipe_through [:api]

    route(:get, "/", Helix.Request1)
    route(:post, "/login", Helix.Account.Requests.Login)
    route(:post, "/sync", Helix.Account.Requests.Sync)
    route(:get, "/check-session", Helix.Session.Requests.Check)
    route(:get, "/subscribe", Helix.Session.Requests.Subscribe)
    route(:post, "/logout", Helix.Account.Requests.Logout)
    route(:get, "/ping", Helix.Session.Requests.Ping)

    scope "/account" do
      post "/join", HelixController, :index

      route(:get, "/test", Helix.Account.Requests.Test)
    end

    scope "/server/:server_cid" do
      post "/", HelixController, :index
      post "/join", HelixController, :index

      scope "/log" do
        route(:post, "/", Helix.Log.Requests.Forge.Create)

        scope "/:log_id" do
          route(:post, "/edit", Helix.Log.Requests.Forge.Edit)
        end
      end

      route(:get, "/test", Helix.Account.Requests.Test)
    end
  end
end
