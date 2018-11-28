defmodule Helix.Webserver.Plugs.RequestID do

  import Plug.Conn

  alias Helix.Webserver.Request.ID, as: RequestIDWeb

  @header "x-request-id"

  def init(opts),
    do: opts

  def call(conn, _opts) do
    request_id = RequestIDWeb.generate_id(conn)

    conn
    |> assign(:request_id, request_id)
    |> put_resp_header(@header, request_id)
  end
end
