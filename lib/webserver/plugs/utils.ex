defmodule Helix.Webserver.Plugs.Utils do

  def json_body(data) do
    Phoenix.json_library().encode_to_iodata!(data)
  end
end
