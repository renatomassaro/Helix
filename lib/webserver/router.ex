defmodule Helix.Webserver.Router do
  use Helix.Webserver, :router

  # TODO: Cors should be added on error pages as well (4xx, 5xx)
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
    route(:get, "/ping", Helix.Session.Request.Ping)
    route(:post, "/logout", Helix.Account.Request.Logout)

    scope "/account" do
      route(:post, "/register", Helix.Account.Request.Register)
      route(:post, "/check-username", Helix.Account.Request.CheckUsername)
      route(:post, "/check-email", Helix.Account.Request.CheckEmail)
      route(:post, "/verify", Helix.Account.Request.Verify)
      route(:get, "/check-verify", Helix.Account.Request.CheckVerify)
    end

    route(:post, "/document/tos/sign", Helix.Account.Request.Document.Sign)
    route(:post, "/document/pp/sign", Helix.Account.Request.Document.Sign)
    route(:get, "/document/tos", Helix.Account.Request.Document.Fetch)
    route(:get, "/document/pp", Helix.Account.Request.Document.Fetch)

    # scope "/public" do
    #   route(:get, "/documents/tos", Helix.Account.Request.GetDocument)
    #   route(:get, "/documents/pp", Helix.Account.Request.GetDocument)
    #   route(:post, "/documents/tos/sign", Helix.Account.Request.SignDocument)
    #   route(:post, "/documents/pp/sign", Helix.Account.Request.SignDocument)
    # end

    # scope "/notification" do
    #   route(:post "/read/all", TODO)
    #   route(:post "/read/$id")
    # end

    scope "/bounce" do
      route(:post, "/", Helix.Network.Request.Bounce.Create)

      scope "/:bounce_id" do
        route(:put, "/", Helix.Network.Request.Bounce.Update)
        route(:delete, "/", Helix.Network.Request.Bounce.Remove)
      end
    end

    # TODO: This belongs within the `gateway` scope
    scope "/virus" do
      route(:post, "/collect", Helix.Software.Request.Virus.Collect)
    end

    scope "/gateway/:gateway_id" do
      scope "/bruteforce" do
        route(:post, "/:target_nip", Helix.Software.Request.Cracker.Bruteforce)
      end

      # scope "/pftp" do
      #   scope "/server" do
      #     route(:post, "/", Helix.Software.Request.PFTP.Server.Enable)
      #     route(:delete, "/", Helix.Software.Request.PFTP.Server.Disable)
      #   end

      #   scope "/file/:file_id" do
      #     route(:post, "/", Helix.Software.Request.PFTP.File.Add)
      #     route(:delete, "/", Helix.Software.Request.PFTP.File.Remove)
      #   end
      # end
    end

    scope "/server/:server_cid" do
      route(:get, "/browse", Helix.Network.Request.Browse)

      scope "/log" do
        route(:get, "/", Helix.Log.Request.Paginate)
        route(:post, "/", Helix.Log.Request.Forge.Create)
        route(:post, "/recover", Helix.Log.Request.Recover.Global)

        scope "/:log_id" do
          route(:post, "/edit", Helix.Log.Request.Forge.Edit)
          route(:post, "/recover", Helix.Log.Request.Recover.Custom)
        end
      end

      scope "/file" do
        scope "/:file_id" do
          route(:post, "/install", Helix.Software.Request.File.Install)
        end
      end
    end

    scope "/endpoint/:endpoint_nip" do
      route(:post, "/login", Helix.Server.Request.Server.Login)

      scope "/file" do
        scope "/:file_id" do
          route(:post, "/download", Helix.Software.Request.File.Download)
          route(:post, "/upload", Helix.Software.Request.File.Upload)
        end
      end

      scope "/pftp/file/:file_id" do
        route(:post, "/download", Helix.Software.Request.PFTP.File.Download)
      end
    end

    scope "/storyline" do
      route(:post, "/reply", Helix.Story.Request.Email.Reply)
      route(:post, "/restart", Helix.Story.Request.Restart)
    end
  end
end
