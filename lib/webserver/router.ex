defmodule Helix.Webserver.Router do
  use Helix.Webserver, :router

  import Helix.Webserver.Router.Macros

  pipeline :api do
    plug :accepts, ["json", "txt"]
    plug Helix.Webserver.Plugs.Entrypoint
    plug Helix.Webserver.Plugs.RequestID
    plug Helix.Webserver.Plugs.CSRFHandler
    plug Helix.Webserver.Plugs.SessionHandler
    plug Helix.Webserver.Plugs.RequestID
    plug Helix.Webserver.Plugs.RequestRouter
  end

  scope "/v1", as: :api_v1 do
    pipe_through [:api]

    route(:post, "/login", Helix.Account.Request.Login)
    route(:post, "/sync", Helix.Account.Request.Sync)
    route(:get, "/check-session", Helix.Session.Request.Check)
    route(:get, "/subscribe", Helix.Session.Request.Subscribe)
    route(:post, "/logout", Helix.Account.Request.Logout)
    route(:get, "/ping", Helix.Session.Request.Ping)

    scope "/server/:server_cid" do
      scope "/log" do
        route(:get, "/", Helix.Log.Request.Paginate)
        route(:post, "/", Helix.Log.Request.Forge.Create)
        route(:post, "/recover", Helix.Log.Request.Recover.Global)

        scope "/:log_id" do
          route(:post, "/edit", Helix.Log.Request.Forge.Edit)
          route(:post, "/recover", Helix.Log.Request.Recover.Custom)
        end
      end
    end
  end
end
