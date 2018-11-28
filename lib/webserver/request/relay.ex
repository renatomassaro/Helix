defmodule Helix.Webserver.Request.Relay do

  alias Plug.Conn
  alias Helix.Webserver.Request

  defstruct [:request_id]

  @type t ::
    %__MODULE__{
      request_id: Webserver.Request.id
    }

  @spec new(Conn.t) ::
    t
  def new(conn = %Conn{}) do
    %__MODULE__{
      request_id: conn.assigns.request_id
    }
  end
end
