defmodule Helix.Test.Webserver do

  alias Helix.Test.Webserver.SSEClient

  defmacro __using__(_) do
    quote do
      import Helix.Test.Webserver
      import Helix.Test.Webserver.Asserts
      import Helix.Test.Webserver.Conn

      alias Helix.Test.Session.Setup, as: SessionSetup
      alias Helix.Test.Webserver.Helper, as: WebserverHelper
      alias Helix.Test.Webserver.Setup, as: WebserverSetup
      alias Helix.Test.Webserver.SSEClient
    end
  end

  defmacro sse_subscribe(session) do
    quote do
      {:ok, sse_client_pid} = SSEClient.start(unquote(session))

      var!(sse_client_pid) = sse_client_pid
    end
  end

  defmacro wait_events(events) do
    quote do
      SSEClient.wait_events(var!(sse_client_pid), unquote(events))
    end
  end
end
