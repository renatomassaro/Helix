defmodule Helix.MQ.Server do

  alias Helix.MQ

  def start_link(port \\ 5000) do
    :ranch.start_listener(
      make_ref(),
      :ranch_tcp,
      [{:ip, {0, 0, 0, 0}}, {:port, port}],
      MQ.Protocol,
      []
    )
  end
end
